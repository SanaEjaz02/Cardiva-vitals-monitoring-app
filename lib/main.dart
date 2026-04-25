import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Local notifications ─────────────────────────────────────────────────────
  await NotificationService.initialize();

  // ── Supabase (configure via dart-define when credentials are ready) ─────────
  // await Supabase.initialize(
  //   url: const String.fromEnvironment('SUPABASE_URL'),
  //   anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  // );

  runApp(
    // ProviderScope is required for Riverpod — wraps the entire widget tree.
    const ProviderScope(child: CardivApp()),
  );
}
