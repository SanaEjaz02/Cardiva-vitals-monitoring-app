// Re-exports healthEventProvider for screens that only care about status.
// Import this file in UI layers that don't need the full vital_provider setup.
export 'vital_provider.dart' show healthEventProvider;
