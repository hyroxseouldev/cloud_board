import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/feature/operations/data/datasources/store_operations_local_data_source.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/audience_branding_model.dart';
import 'package:cloud_board/src/app/feature/operations/data/repositories/audience_branding_stream.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/audience_branding.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/audience_branding_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Map<String, dynamic> projection({
  String owner = 'owner-a',
  bool visible = false,
  String scope = 'all-audience',
  int revision = 5,
  int projectionRevision = 8,
  int appliedAtMs = 7000,
  int validUntilMs = 9000,
}) => {
  'ownerId': owner,
  'policyVersion': 'plan-entitlements-v2',
  'audienceLogoVersion': 'audience-logo-v1',
  'audienceLogoScope': scope,
  'showCloudBoardLogo': visible,
  'revision': revision,
  'projectionRevision': projectionRevision,
  'appliedAtMs': appliedAtMs,
  'validUntilMs': validUntilMs,
};

AudienceBrandingModel model({
  String owner = 'owner-a',
  bool visible = false,
  int revision = 5,
  int projectionRevision = 8,
  int validUntilMs = 9000,
}) => AudienceBrandingModel.parse(
  projection(
    owner: owner,
    visible: visible,
    revision: revision,
    projectionRevision: projectionRevision,
    validUntilMs: validUntilMs,
  ),
  owner,
)!;

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('only a complete server projection for this owner is accepted', () {
    final value = projection();
    expect(
      AudienceBrandingModel.parse(
        value,
        'owner-a',
      )?.toEntity().includesClassScreens,
      isTrue,
    );
    expect(AudienceBrandingModel.parse(value, 'owner-b'), isNull);
    expect(
      AudienceBrandingModel.parse({'showCloudBoardLogo': true}, 'owner-a'),
      isNull,
    );
    for (final field in [
      'ownerId',
      'policyVersion',
      'audienceLogoVersion',
      'audienceLogoScope',
      'showCloudBoardLogo',
      'revision',
      'projectionRevision',
      'appliedAtMs',
      'validUntilMs',
    ]) {
      expect(
        AudienceBrandingModel.parse({...value}..remove(field), 'owner-a'),
        isNull,
        reason: field,
      );
    }
    for (final patch in [
      {'audienceLogoVersion': 'future'},
      {'audienceLogoScope': 'free'},
      {'policyVersion': 'plan-entitlements-v1'},
      {'showCloudBoardLogo': 'false'},
      {'revision': -1},
      {'projectionRevision': 1.5},
      {'validUntilMs': 7000},
      {'validUntilMs': double.infinity},
      {'appliedAtMs': double.nan},
    ]) {
      expect(
        AudienceBrandingModel.parse({...value, ...patch}, 'owner-a'),
        isNull,
      );
    }
    expect(AudienceBrandingModel.parse({1: 'bad'}, 'owner-a'), isNull);
  });

  test(
    'logo cache is separate from editable brand and scoped to owner',
    () async {
      final prefs = SharedPreferencesAsync();
      final first = StoreOperationsLocalDataSource(prefs, ownerId: 'owner-a');
      final second = StoreOperationsLocalDataSource(prefs, ownerId: 'owner-b');
      await first.saveAudienceBranding(model());
      expect((await first.loadAudienceBranding())?.showCloudBoardLogo, isFalse);
      expect(await second.loadAudienceBranding(), isNull);
      await second.saveAudienceBranding(model());
      expect(await second.loadAudienceBranding(), isNull);
      expect(
        await StoreOperationsLocalDataSource(prefs).loadAudienceBranding(),
        isNull,
      );
      // A value copied from another account, an old brand payload, or corrupt
      // local storage cannot introduce a policy for this account.
      for (final value in [
        projection(owner: 'owner-b'),
        {'showCloudBoardLogo': false},
      ]) {
        await prefs.setString(
          'operations.audienceBranding.v1.owner-a',
          jsonEncode(value),
        );
        expect(await first.loadAudienceBranding(), isNull);
      }
      await prefs.setString(
        'operations.audienceBranding.v1.owner-a',
        '{broken',
      );
      expect(await first.loadAudienceBranding(), isNull);
    },
  );

  test('unknown and errors never become a Free logo policy', () async {
    final remote = StreamController<AudienceBrandingModel?>();
    final values = <AudienceBranding?>[];
    final subscription = watchConfirmedAudienceBranding(
      nowMs: () => 8000,
      ownerId: 'owner-a',
      loadCached: () async => null,
      saveCached: (_) async {},
      watchRemote: () => remote.stream,
    ).listen(values.add);
    await flush();
    remote.add(null);
    remote.addError(StateError('permission-denied'));
    await flush();
    expect(values, [null]);
    await subscription.cancel();
    await remote.close();
  });

  test(
    'a new install does not adopt an already expired remote projection',
    () async {
      final remote = StreamController<AudienceBrandingModel?>();
      final values = <AudienceBranding?>[];
      final saved = <AudienceBrandingModel>[];
      final subscription = watchConfirmedAudienceBranding(
        ownerId: 'owner-a',
        nowMs: () => 10000,
        loadCached: () async => null,
        saveCached: (value) async => saved.add(value),
        watchRemote: () => remote.stream,
      ).listen(values.add);
      await flush();
      remote.add(model());
      await flush();
      expect(values, [null]);
      expect(saved, isEmpty);
      remote.add(model(projectionRevision: 9, validUntilMs: 20000));
      await flush();
      expect(values.last!.showCloudBoardLogo, isFalse);
      expect(saved.single.projectionRevision, 9);
      await subscription.cancel();
      await remote.close();
    },
  );

  test('transaction revision orders changes across server clock skew', () {
    final previous = model();
    final laterCommit = AudienceBrandingModel.parse(
      projection(projectionRevision: 9, appliedAtMs: 6999, visible: true),
      'owner-a',
    )!;
    expect(laterCommit.supersedes(previous), isTrue);
    expect(model(visible: true).supersedes(previous), isFalse);
    expect(previous.supersedes(previous), isTrue);
  });

  test(
    'refresh during the first disk write retains confirmed policy after expiry',
    () async {
      final memory = AudienceBrandingMemory();
      final blockedWrite = Completer<void>();
      final oldRemote = StreamController<AudienceBrandingModel?>();
      final newRemote = StreamController<AudienceBrandingModel?>();
      final oldSubscription = watchConfirmedAudienceBranding(
        ownerId: 'owner-a',
        nowMs: () => 8000,
        memory: memory,
        loadCached: () async => null,
        saveCached: (_) => blockedWrite.future,
        watchRemote: () => oldRemote.stream,
      ).listen((_) {});
      await flush();
      oldRemote.add(model());
      await flush();
      final oldCancellation = oldSubscription.cancel();
      final values = <AudienceBranding?>[];
      final newSubscription = watchConfirmedAudienceBranding(
        ownerId: 'owner-a',
        nowMs: () => 10000,
        memory: memory,
        loadCached: () async =>
            throw StateError('must not wait for pending disk'),
        saveCached: (_) async {},
        watchRemote: () => newRemote.stream,
      ).listen(values.add);
      await flush();
      newRemote.add(
        model(),
      ); // Expired: may preserve a confirmed cache, not enroll.
      await flush();
      expect(values.length, 1);
      expect(values.single!.showCloudBoardLogo, isFalse);
      blockedWrite.complete();
      await oldCancellation;
      await newSubscription.cancel();
      await oldRemote.close();
      await newRemote.close();
    },
  );

  test(
    'cancel and reconnect cannot let old disk writes replace latest policy',
    () async {
      final prefs = _DelayedPreferences();
      final oldSource = StoreOperationsLocalDataSource(
        prefs,
        ownerId: 'owner-a',
      );
      final newSource = StoreOperationsLocalDataSource(
        prefs,
        ownerId: 'owner-a',
      );
      final oldRemote = StreamController<AudienceBrandingModel?>();
      final newRemote = StreamController<AudienceBrandingModel?>();
      Stream<AudienceBranding?> watch(
        StoreOperationsLocalDataSource source,
        StreamController<AudienceBrandingModel?> remote,
      ) => watchConfirmedAudienceBranding(
        ownerId: 'owner-a',
        nowMs: () => 8000,
        loadCached: source.loadAudienceBranding,
        saveCached: source.saveAudienceBranding,
        watchRemote: () => remote.stream,
      );
      final oldSubscription = watch(oldSource, oldRemote).listen((_) {});
      await flush();
      oldRemote.add(model());
      await prefs.started.future;
      final oldCancellation = oldSubscription.cancel();
      final values = <AudienceBranding?>[];
      final newSubscription = watch(newSource, newRemote).listen(values.add);
      await flush();
      newRemote.add(model(projectionRevision: 9, visible: true));
      await flush();
      expect(values.last!.projectionRevision, 9);
      prefs.release.complete();
      await oldCancellation;
      await newSubscription.cancel();
      expect((await newSource.loadAudienceBranding())!.projectionRevision, 9);
      // A late queued event from the old subscription is checked against disk too.
      await oldSource.saveAudienceBranding(model());
      expect((await newSource.loadAudienceBranding())!.projectionRevision, 9);
      await oldRemote.close();
      await newRemote.close();
    },
  );

  test(
    'last confirmed paid hide survives expiry, offline error and reconnect',
    () async {
      final first = StreamController<AudienceBrandingModel?>();
      final second = StreamController<AudienceBrandingModel?>();
      var connections = 0;
      final values = <AudienceBranding?>[];
      final subscription = watchConfirmedAudienceBranding(
        nowMs: () => 10000,
        ownerId: 'owner-a',
        loadCached: () async => model(),
        saveCached: (_) async {},
        watchRemote: () => ++connections == 1 ? first.stream : second.stream,
        retryDelay: const Duration(milliseconds: 1),
      ).listen(values.add);
      await flush();
      first.add(null);
      first.addError(StateError('offline'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(connections, 2);
      expect(values.map((v) => v?.showCloudBoardLogo), [false]);
      expect(values.single!.classScreensAvailableAt(10000), isFalse);
      second.add(
        model(
          visible: true,
          revision: 6,
          projectionRevision: 9,
          validUntilMs: 20000,
        ),
      );
      await flush();
      expect(values.map((v) => v?.showCloudBoardLogo), [false, true]);
      await subscription.cancel();
      await first.close();
      await second.close();
    },
  );

  test(
    'replayed revisions and another owner cannot overwrite confirmed policy',
    () async {
      final remote = StreamController<AudienceBrandingModel?>();
      final values = <AudienceBranding?>[];
      final saved = <AudienceBrandingModel>[];
      final subscription = watchConfirmedAudienceBranding(
        nowMs: () => 8000,
        ownerId: 'owner-a',
        loadCached: () async => model(),
        saveCached: (value) async => saved.add(value),
        watchRemote: () => remote.stream,
      ).listen(values.add);
      await flush();
      remote.add(model(visible: true, revision: 4, projectionRevision: 9));
      remote.add(model(visible: true, revision: 5, projectionRevision: 7));
      remote.add(
        model(
          owner: 'owner-b',
          visible: true,
          revision: 6,
          projectionRevision: 9,
        ),
      );
      await flush();
      expect(values.map((v) => v?.showCloudBoardLogo), [false]);
      expect(saved, isEmpty);
      // Setting changes need their own revision even when entitlement is unchanged.
      remote.add(model(visible: true, revision: 5, projectionRevision: 9));
      await flush();
      expect(values.last!.showCloudBoardLogo, isTrue);
      expect(saved.single.projectionRevision, 9);
      await subscription.cancel();
      await remote.close();
    },
  );

  test(
    'storage failures do not prevent live policy and writes stay ordered',
    () async {
      final remote = StreamController<AudienceBrandingModel?>();
      final blockedWrite = Completer<void>();
      final writes = <int>[];
      final values = <AudienceBranding?>[];
      final subscription = watchConfirmedAudienceBranding(
        nowMs: () => 8000,
        ownerId: 'owner-a',
        loadCached: () async => throw StateError('disk'),
        saveCached: (value) async {
          writes.add(value.projectionRevision);
          if (writes.length == 1) await blockedWrite.future;
        },
        watchRemote: () => remote.stream,
      ).listen(values.add);
      await flush();
      remote.add(model());
      remote.add(model(visible: true, projectionRevision: 9));
      await flush();
      expect(values.last!.showCloudBoardLogo, isTrue);
      expect(writes, [8]);
      blockedWrite.complete();
      await flush();
      expect(writes, [8, 9]);
      await subscription.cancel();
      await remote.close();
    },
  );

  test(
    'signed out or owner changed never reads another owner cached policy',
    () async {
      final remote = StreamController<AudienceBrandingModel?>();
      final values = <AudienceBranding?>[];
      final subscription = watchConfirmedAudienceBranding(
        nowMs: () => 8000,
        ownerId: 'owner-b',
        loadCached: () async => model(owner: 'owner-a'),
        saveCached: (_) async {},
        watchRemote: () => remote.stream,
      ).listen(values.add);
      await flush();
      expect(values, [null]);
      remote.add(model(owner: 'owner-b', visible: true));
      await flush();
      expect(values.last!.ownerId, 'owner-b');
      await subscription.cancel();
      await remote.close();
    },
  );

  test('product copy expands only for an active all-audience projection', () {
    final enabled = model().toEntity();
    final standby = AudienceBrandingModel.parse(
      projection(scope: 'standby'),
      'owner-a',
    )!.toEntity();
    expect(audienceClassBrandingAvailable(enabled, nowMs: 8000), isTrue);
    expect(audienceClassBrandingAvailable(enabled, nowMs: 9000), isFalse);
    expect(audienceClassBrandingAvailable(standby, nowMs: 8000), isFalse);
    expect(audienceClassBrandingAvailable(null, nowMs: 8000), isFalse);
    expect(
      audienceLogoBenefit(canHideLogo: false, classScreensAvailable: true),
      '대기·수업 화면 CloudBoard 로고 고정 표시',
    );
    expect(
      audienceLogoBenefit(canHideLogo: true, classScreensAvailable: true),
      '대기·수업 화면 CloudBoard 로고 숨김 가능',
    );
    expect(
      audienceLogoBenefit(canHideLogo: true, classScreensAvailable: false),
      '대기 화면 CloudBoard 로고 숨김 가능',
    );
  });
}

class _DelayedPreferences extends SharedPreferencesAsync {
  final started = Completer<void>();
  final release = Completer<void>();
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    values[key] = value;
  }
}
