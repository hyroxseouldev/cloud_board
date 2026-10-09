import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/ai_slide_design_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slide_design_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  bool get isAnonymous => false;
}

class _Auth extends Fake implements FirebaseAuth {
  User? user = _User('alice');
  @override
  User? get currentUser => user;
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final updates =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => updates.stream;
}

class _Firestore extends Fake implements FirebaseFirestore {
  final values = _Collection();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users/alice/aiSlideDesigns');
    return values;
  }
}

class _CallableResult<T> extends Fake implements HttpsCallableResult<T> {
  _CallableResult(this.data);
  @override
  final T data;
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.name, this.calls);
  final String name;
  final List<(String, dynamic)> calls;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    calls.add((name, parameters));
    return _CallableResult(
      <String, dynamic>{
        'premium': true,
        'enabled': true,
        'remaining': 27,
        'limit': 30,
      } as T,
    );
  }
}

class _Functions extends Fake implements FirebaseFunctions {
  final calls = <(String, dynamic)>[];
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _Callable(name, calls);
}

// ignore: must_be_immutable
class _Preferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  final reads = <String>[];
  Completer<void>? pending;
  @override
  Future<String?> getString(String key) async {
    reads.add(key);
    await pending?.future;
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late _Auth auth;
  late _Firestore firestore;
  late _Preferences preferences;
  late AiSlideDesignDataSource source;
  late _Functions functions;
  AiSlideDesignModel design(String? storeId, [int index = 0]) =>
      AiSlideDesignModel.fromEntity(
        aiSlideDesignCatalog[index].copyWith(storeId: storeId),
      );
  setUp(() {
    auth = _Auth();
    firestore = _Firestore();
    preferences = _Preferences();
    functions = _Functions();
    source = AiSlideDesignDataSource(firestore, auth, functions, preferences);
  });
  tearDown(() => firestore.values.updates.close());

  test('quota uses the deployed shared endpoint while generation uses the design endpoint', () async {
    final usage = await source.call('alice', {'action': 'status'});
    expect(usage['remaining'], 27);
    expect(functions.calls.single.$1, 'cloudboardAiSlides');
    expect(functions.calls.single.$2, {'action': 'status'});
    await source.call('alice', {'action': 'generate', 'prompt': '밝은 스타일'});
    expect(functions.calls.last.$1, 'cloudboardAiSlideDesigns');
    auth.user = _User('bob');
    await expectLater(
      source.call('alice', {'action': 'status'}),
      throwsA(isA<AiSlidesFailure>()),
    );
    expect(functions.calls, hasLength(2));
  });

  test(
    'linking a center retains legacy templates and excludes other centers',
    () async {
      final first = source.watchTemplates('alice', 'center-a').first;
      firestore.values.updates.add(
        _Snapshot([
          _Document('legacy-class', design(null).toJson()),
          _Document('current-class', design('center-a').toJson()),
          _Document('other-class', design('center-b').toJson()),
        ]),
      );
      expect((await first).map((value) => value.$1), [
        'legacy-class',
        'current-class',
      ]);
      final legacyOnly = source.watchTemplates('alice', null).first;
      firestore.values.updates.add(
        _Snapshot([
          _Document('legacy-class', design(null).toJson()),
          _Document('current-class', design('center-a').toJson()),
        ]),
      );
      expect((await legacyOnly).map((value) => value.$1), ['legacy-class']);
    },
  );

  test(
    'center selection overrides legacy fallback without rewriting it',
    () async {
      await source.saveSelected('alice', null, 'legacy-class', design(null));
      var selected = await source.loadSelected('alice', 'center-a');
      expect(selected!.$1, 'legacy-class');
      expect(selected.$2.storeId, isNull);
      await source.saveSelected(
        'alice',
        'center-a',
        'current-class',
        design('center-a', 1),
      );
      selected = await source.loadSelected('alice', 'center-a');
      expect(selected!.$1, 'current-class');
      expect(selected.$2.storeId, 'center-a');
      expect((await source.loadSelected('alice', null))!.$1, 'legacy-class');
    },
  );

  test(
    'legacy fallback never reads a different owner or explicit center',
    () async {
      await source.saveSelected(
        'alice',
        'center-b',
        'other-center',
        design('center-b'),
      );
      expect(await source.loadSelected('alice', 'center-a'), isNull);
      await source.saveSelected('alice', null, 'alice-legacy', design(null));
      auth.user = _User('bob');
      preferences.reads.clear();
      expect(await source.loadSelected('bob', 'center-bob'), isNull);
      expect(preferences.reads.every((key) => key.contains('.bob.')), isTrue);
    },
  );

  test(
    'account switch while loading prevents a stale legacy selection',
    () async {
      await source.saveSelected('alice', null, 'legacy-class', design(null));
      preferences.pending = Completer<void>();
      final loading = source.loadSelected('alice', 'center-a');
      await Future<void>.delayed(Duration.zero);
      auth.user = _User('bob');
      final assertion = expectLater(loading, throwsA(isA<AiSlidesFailure>()));
      preferences.pending!.complete();
      await assertion;
    },
  );
}
