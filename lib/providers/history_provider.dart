import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vital_reading.dart';
import 'vital_provider.dart';

/// Accumulates VitalReading objects in memory as they arrive from MockDataService.
/// Keeps the most recent 120 readings (≈ 4 minutes of data at 2-second intervals).
class ReadingHistoryNotifier extends StateNotifier<List<VitalReading>> {
  ReadingHistoryNotifier(Ref ref) : super([]) {
    ref.listen<AsyncValue<VitalReading>>(latestReadingProvider, (_, next) {
      next.whenData((reading) {
        state = [reading, ...state].take(120).toList();
      });
    });
  }
}

final historyProvider =
    StateNotifierProvider<ReadingHistoryNotifier, List<VitalReading>>(
  (ref) => ReadingHistoryNotifier(ref),
);
