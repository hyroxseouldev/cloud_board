import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/update_news/data/datasources/update_news_data_source.dart';
import 'package:cloud_board/src/app/feature/update_news/data/repositories/update_news_repository_impl.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/entities/update_news.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/repositories/update_news_repository.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/usecases/update_news_actions.dart';
import 'package:cloud_board/src/app/feature/update_news/presentation/controllers/update_news_controller.dart';
import 'package:cloud_board/src/app/feature/update_news/presentation/views/update_news_screen.dart';
import 'package:cloud_board/src/app/feature/update_news/presentation/widgets/update_news_tile.dart';

const user = AuthUser(
  id: 'reader',
  email: 'reader@example.invalid',
  displayName: 'Reader',
  photoUrl: null,
);
UpdateNews news(
  String id, {
  String date = '2026-09-30',
  Map<String, String>? builds,
}) => UpdateNews(
  id: id,
  title: '$id 업데이트',
  summary: '수업 준비와 진행이 더 편해졌어요.',
  date: date,
  version: '1.0.0',
  builds: builds ?? {'ios': '540', 'android': '50', 'web': '82.2'},
  items: const [
    UpdateNewsItem(title: '이메일로 시작하세요', body: '로그인 화면에서 이메일로 계속하기를 선택하세요.'),
    UpdateNewsItem(title: '워크아웃을 찾아보세요', body: '목록을 아래로 당기면 최신 내용으로 새로고침돼요.'),
    UpdateNewsItem(
      title: '바로 수업을 시작하세요',
      body: '바로 시작을 누르면 준비 시간을 마치고 현재 운동을 시작해요.',
    ),
  ],
);

class NewsRepository implements UpdateNewsRepository {
  List<UpdateNews> notes = [news('new'), news('old', date: '2026-09-29')];
  InstalledRelease release = (platform: 'ios', version: '1.0.0', build: '540');
  final reads = <String, Set<String>>{};
  final writes = <String>[];
  bool fail = false, failWrite = false;
  Completer<void>? writeGate;
  @override
  Future<List<UpdateNews>> load() async {
    if (fail) throw StateError('연결을 확인해 주세요.');
    return notes;
  }

  @override
  Future<InstalledRelease> installed() async => release;
  @override
  Future<Set<String>> readIds(String uid) async => {...?reads[uid]};
  @override
  Future<void> saveReadIds(String uid, Set<String> ids) async {
    await writeGate?.future;
    if (failWrite) throw StateError('write failed');
    reads[uid] = {...ids};
    writes.add(uid);
  }
}

class FeedSource extends UpdateNewsDataSource {
  FeedSource(this.feed);
  final Map<String, dynamic> feed;
  @override
  Future<Map<String, dynamic>?> load() async => feed;
}

void main() {
  test(
    'filters unavailable platform/version/build and sorts eligible history',
    () async {
      final repository = NewsRepository();
      repository.notes = [
        news('old', date: '2026-09-20'),
        news('future', builds: {'ios': '541'}),
        news('new'),
        news('other-platform', builds: {'web': '80.1'}),
        news('version').copyWith(version: '1.1.0'),
      ];
      expect(
        (await UpdateNewsActions(repository).load('reader')).notes
            .map((n) => n.id),
        ['new', 'old'],
      );
      repository.release = (platform: 'web', version: '1.0.0', build: '82.10');
      expect(
        (await UpdateNewsActions(repository).load('reader')).notes
            .map((n) => n.id),
        ['new', 'other-platform', 'old'],
      );
      repository.release = (
        platform: 'ios',
        version: '1.0.0',
        build: 'unknown',
      );
      expect(
        (await UpdateNewsActions(repository).load('reader')).notes,
        isEmpty,
      );
      expect(compareReleaseNumbers('82.10', '82.2'), greaterThan(0));
    },
  );

  test(
    'malformed entry does not hide valid history, malformed feed is retryable',
    () async {
      final value = {
        'id': 'valid',
        'title': '새로운 소식',
        'summary': '소개',
        'date': '2026-09-30',
        'version': '1.0.0',
        'builds': {'ios': '540'},
        'items': [
          {'title': '기능', 'body': '사용 방법'},
        ],
      };
      final repository = FirebaseUpdateNewsRepository(
        FeedSource({
          'schemaVersion': 1,
          'entries': [
            value,
            {...value, 'id': '../unsafe'},
            {'bad': true},
          ],
        }),
      );
      expect((await repository.load()).single.id, 'valid');
      await expectLater(
        FirebaseUpdateNewsRepository(FeedSource({'schemaVersion': 2})).load(),
        throwsFormatException,
      );
    },
  );

  test(
    'read state persists separately for each account on this device',
    () async {
      SharedPreferences.setMockInitialValues({});
      final source = UpdateNewsDataSource();
      await source.saveReadIds('reader', {'news-a'});
      expect(await UpdateNewsDataSource().readIds('reader'), {'news-a'});
      expect(await source.readIds('another'), isEmpty);
    },
  );

  test('rapid detail reads serialize, and old account writes cannot affect new account', () async {
    final repository = NewsRepository();
    final users = StreamController<AuthUser?>();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => users.stream),
        updateNewsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final subscription = container.listen(
      updateNewsControllerProvider,
      (_, _) {},
    );
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await users.close();
    });
    users.add(user);
    await container.read(authStateProvider.future);
    await container.read(updateNewsControllerProvider.future);
    final controller = container.read(updateNewsControllerProvider.notifier);
    await Future.wait([controller.markRead('new'), controller.markRead('old')]);
    expect(repository.reads['reader'], {'new', 'old'});
    expect(
      container.read(updateNewsControllerProvider).requireValue.hasUnread,
      isFalse,
    );
    repository.reads.clear();
    container.invalidate(updateNewsControllerProvider);
    await container.read(updateNewsControllerProvider.future);
    repository.writeGate = Completer<void>();
    final writing = controller.markRead('new');
    await Future<void>.delayed(Duration.zero);
    users.add(user.copyWith(id: 'another'));
    await Future<void>.delayed(Duration.zero);
    await container.read(updateNewsControllerProvider.future);
    repository.writeGate!.complete();
    await writing;
    expect(
      container.read(updateNewsControllerProvider).requireValue.readIds,
      isEmpty,
    );
    expect(repository.reads['another'], isNull);
  });

  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    testWidgets(
      'settings opens news, detail marks only opened item, returns with state at $size',
      (tester) async {
        final repository = NewsRepository();
        final container = await mount(tester, repository, size: size);
        expect(
          find.byKey(const ValueKey('update-news-unread')),
          findsOneWidget,
        );
        await tester.tap(find.text('업데이트 소식'));
        await tester.pumpAndSettle();
        expect(repository.writes, isEmpty);
        expect(find.text('NEW'), findsNWidgets(2));
        await tester.tap(find.text('new 업데이트'));
        await tester.pumpAndSettle();
        expect(find.text('이메일로 시작하세요'), findsOneWidget);
        expect(repository.reads['reader'], {'new'});
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        expect(find.text('바로 수업을 시작하세요').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('뒤로'));
        await tester.pumpAndSettle();
        expect(find.text('NEW'), findsOneWidget);
        await tester.tap(find.byTooltip('뒤로'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('update-news-unread')),
          findsOneWidget,
        );
        await container
            .read(updateNewsControllerProvider.notifier)
            .markRead('old');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('update-news-unread')), findsNothing);
      },
    );
  }

  testWidgets(
    'loading failure retries, empty state and unknown detail stay readable',
    (tester) async {
      final repository = NewsRepository()..fail = true;
      await mount(tester, repository);
      await tester.tap(find.text('업데이트 소식'));
      await tester.pumpAndSettle();
      expect(find.text('다시 시도'), findsOneWidget);
      repository.fail = false;
      repository.notes = [];
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('아직 등록된 업데이트 소식이 없어요.'), findsOneWidget);
      final context = tester.element(find.byType(UpdateNewsScreen));
      context.push('/profile/updates/missing');
      await tester.pumpAndSettle();
      expect(find.text('이 버전에서 확인할 수 없는 소식이에요.'), findsOneWidget);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'read persistence failure retains badge and can retry without losing content',
    (tester) async {
      final repository = NewsRepository()..failWrite = true;
      await mount(tester, repository);
      await tester.tap(find.text('업데이트 소식'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('new 업데이트'));
      await tester.pumpAndSettle();
      expect(find.text('읽은 상태를 저장하지 못했어요.'), findsOneWidget);
      expect(find.text('이메일로 시작하세요'), findsOneWidget);
      repository.failWrite = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(repository.reads['reader'], {'new'});
    },
  );
}

Future<ProviderContainer> mount(
  WidgetTester tester,
  NewsRepository repository, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      updateNewsRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('설정')),
          body: const Padding(
            padding: EdgeInsets.all(20),
            child: UpdateNewsTile(),
          ),
        ),
        routes: [
          GoRoute(
            path: 'updates',
            builder: (_, _) => const UpdateNewsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    UpdateNewsDetailScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: XonTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
