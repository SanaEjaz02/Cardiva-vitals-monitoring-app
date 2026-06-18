import 'package:flutter/material.dart';

/// Global navigator key — used by NotificationService to deep-link
/// into the correct screen when the user taps a system notification,
/// even when the app is in the background.
final appNavigatorKey = GlobalKey<NavigatorState>();
