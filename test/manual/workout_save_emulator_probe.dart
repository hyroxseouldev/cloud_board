@TestOn('browser')
library;

// The manual browser harness registers the real implementations already pulled
// in by the app's Firebase/SharedPreferences plugins, without a mock messenger.
// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/center_slide_catalog_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/center_slide_template_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_creation.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_functions_web/cloud_functions_web.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_web/firebase_storage_web.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

// Not named *_test.dart: opt in using the demo-only emulator runner.
// Every Firebase instance is real and explicitly redirected before first use.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real Flutter repository saves a center PNG through the callable and reads it back', () async {
    if (!const bool.fromEnvironment('STA189_LOCAL_EMULATORS')) {
      throw StateError(
        'Use the local demo emulator runner with explicit opt-in.',
      );
    }
    const project = 'demo-cloudboard-sta189-callable';
    const owner = 'sta189-chrome-owner', center = 'sta189-chrome-center';
    FirebaseCoreWeb.registerWith(webPluginRegistrar);
    FirebaseAuthWeb.registerWith(webPluginRegistrar);
    FirebaseFirestoreWeb.registerWith(webPluginRegistrar);
    FirebaseFunctionsWeb.registerWith(webPluginRegistrar);
    FirebaseStorageWeb.registerWith(webPluginRegistrar);
    SharedPreferencesPlugin.registerWith(webPluginRegistrar);
    webPluginRegistrar.registerMessageHandler();
    debugPrint('STA189 probe: initialize real Firebase web plugins');
    final app = await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'local-emulator-key',
        appId: '1:1234567890:web:1234567890abcdef',
        messagingSenderId: '1234567890',
        projectId: project,
        authDomain: 'localhost',
        storageBucket: '$project.appspot.com',
      ),
    ).timeout(const Duration(seconds: 30));
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 19490);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.useFirestoreEmulator('127.0.0.1', 19480);
    firestore.settings = const Settings(persistenceEnabled: false);
    final functions = FirebaseFunctions.instanceFor(
      app: app,
      region: 'asia-northeast3',
    );
    functions.useFunctionsEmulator('127.0.0.1', 19401);
    final storage = FirebaseStorage.instanceFor(app: app);
    await storage.useStorageEmulator('127.0.0.1', 19499);
    await auth.signInWithEmailAndPassword(
      email: 'sta189-chrome@example.test',
      password: 'local-emulator-only',
    );
    debugPrint('STA189 probe: local Auth signed in');
    expect(auth.currentUser?.uid, owner);
    final document = firestore.doc(
      'centers/$center/slideTemplateCatalog/current',
    );
    final source = CenterSlideCatalogDataSource(
      projectId: project,
      ownerId: owner,
      centerId: center,
      bucket: app.options.storageBucket!,
      isCurrentIdentity: () => auth.currentUser?.uid == owner,
      idToken: () => auth.currentUser!.getIdToken(),
      documents: () => document
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => CenterSlideDocument(
              data: snapshot.data(),
              fromCache: snapshot.metadata.isFromCache,
            ),
          ),
      readServerDocument: () async {
        final snapshot = await document.get(
          const GetOptions(source: Source.server),
        );
        return CenterSlideDocument(
          data: snapshot.data(),
          fromCache: snapshot.metadata.isFromCache,
        );
      },
      client: http.Client(),
    );
    final templates = CenterSlideTemplateRepositoryImpl(source);
    addTearDown(templates.clear);
    final catalog = (await document.get(
      const GetOptions(source: Source.server),
    )).data()!;
    final recipe = CenterSlideRecipe.fromJson(
      Map<String, dynamic>.from(
        (catalog['templates'] as List).single['recipe'] as Map,
      ),
    );
    final draft = AiSlideDraft(
      title: 'Browser PNG',
      layout: 'list',
      lines: const [],
      centerRecipe: recipe,
      workSeconds: 60,
      restSeconds: 0,
      sets: 1,
    );
    final preview = await templates.renderDraft(owner, draft);
    final png = await templates.renderDraft(owner, draft);
    expect(png, preview);
    expect(ByteData.sublistView(png).getUint32(16), 1920);
    expect(ByteData.sublistView(png).getUint32(20), 1080);
    final module = confirmCenterSlide(draft, 'browser-slide', png);
    debugPrint('STA189 probe: preview/Add produced the same 1920x1080 PNG');
    final data = WorkoutFirestoreDataSource(firestore, functions: functions);
    final repository = WorkoutRepositoryImpl(
      auth,
      data,
      WorkoutStorageDataSource(storage),
      WorkoutLocalDataSource(await SharedPreferences.getInstance()),
    );
    final original =
        Workout.empty(
          'browser-lesson',
          const WorkoutAuthor(id: owner, displayName: 'Local', photoUrl: null),
        ).copyWith(
          name: 'Browser created lesson',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          modules: [module],
          brandL: 'Legacy browser brand',
        );
    final first = await repository.save(original);
    debugPrint(
      'STA189 probe: repository saved through Storage and HTTP callable',
    );
    final savedModule = first.modules.single;
    final imageUri = Uri.parse(savedModule.imageSource);
    expect(imageUri.host, '127.0.0.1');
    expect(imageUri.pathSegments[1], 'b');
    expect(imageUri.pathSegments[3], 'o');
    expect(savedModule.designTemplate, isNull);
    expect(savedModule.designStyle, isNull);
    expect(savedModule.designFingerprint, isNull);
    // refFromURL in FlutterFire only parses production HTTPS/gs URLs, whereas
    // this emulator returns a localhost HTTP URL. Read its exact object path.
    final storedImage = storage.ref(imageUri.pathSegments[4]);
    final image = await storedImage.getData();
    expect(image, isNotNull);
    // The existing optimizer preserves this 1920x1080 PNG byte-for-byte.
    expect(sha256.convert(image!).toString(), sha256.convert(png).toString());
    final metadata = await storedImage.getMetadata();
    expect(metadata.contentType, 'image/png');
    expect(metadata.size, png.length);
    final ref = firestore.doc('users/$owner/workouts/browser-lesson');
    await ref.update({
      'futureMetadata': {'retained': true},
    });
    final usage = firestore.doc('users/$owner/planUsage/current');
    final usageBefore = (await usage.get(
      const GetOptions(source: Source.server),
    )).data()!;
    final edited = await repository.save(
      first.copyWith(name: 'Browser edited lesson'),
    );
    final reopened = (await data.loadOne(
      owner,
      edited.id,
      requireServer: true,
    ))!.toEntity();
    expect(reopened.name, 'Browser edited lesson');
    expect(reopened.createdAt.millisecondsSinceEpoch, 1000);
    expect(reopened.brandL, 'Legacy browser brand');
    expect(reopened.modules.single.workSeconds, 60);
    expect(reopened.modules.single.restSeconds, 0);
    expect(reopened.modules.single.sets, 1);
    final raw = (await ref.get(const GetOptions(source: Source.server)))
        .data()!;
    expect(raw['futureMetadata'], {'retained': true});
    final usageAfter = (await usage.get(
      const GetOptions(source: Source.server),
    )).data()!;
    expect(usageAfter['updatedAt'], usageBefore['updatedAt']);
    final summary =
        (await firestore
                .doc('users/$owner/workoutSummaries/browser-lesson')
                .get(const GetOptions(source: Source.server)))
            .data()!;
    expect(summary['name'], 'Browser edited lesson');
    expect(summary['moduleCount'], 1);
    expect(summary['durationSeconds'], 60);
    await repository.delete(edited.id);
    expect(await data.loadOne(owner, edited.id, requireServer: true), isNull);
    final restored = await repository.save(
      edited.copyWith(name: 'Browser restored lesson'),
    );
    expect(
      (await data.loadOne(owner, restored.id, requireServer: true))!.name,
      'Browser restored lesson',
    );
    expect(
      (await usage.get(const GetOptions(source: Source.server)))
          .data()!['workoutCount'],
      1,
    );
    await auth.signOut();
    expect(() => repository.save(restored), throwsStateError);
    await app.delete();
    debugPrint(
      'STA189 probe: server readback, edit, usage, restore and sign-out guard passed',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
