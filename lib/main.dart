import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/realtime_database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://cardiva-30297-default-rtdb.firebaseio.com',
  ).setPersistenceEnabled(true);

  // Safety net: whenever Firebase Auth delivers a sign-in (even if the
  // auth_screen await was dropped due to an activity transition on slow
  // devices), ensure a basic RTDB profile exists for this user.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user == null) return;
    RealtimeDatabaseService.ensureProfileExists(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? '',
    );
  });

  await NotificationService.initialize();
  // Background service disabled — its secondary Flutter engine crash-loops
  // on Infinix XOS (flutter_background_service_android plugin throws), consuming
  // CPU and blocking the Firestore gRPC connection in the main engine.
  // Re-enable once flutter_background_service is updated or runs in a separate process.
  // BackgroundService.initialize();

  runApp(
    const ProviderScope(child: CardivApp()),
  );
}
