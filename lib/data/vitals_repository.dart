import 'dart:math';
import '../models/vital.dart';
import '../theme/app_colors.dart';

class VitalsRepository {
  VitalsRepository._();

  static final VitalsRepository instance = VitalsRepository._();

  final _random = Random();

  // Current live readings — updated by mock BLE stream
  List<Vital> get currentVitals => _mockVitals;

  static final List<Vital> _mockVitals = [
    Vital(
      kind: VitalKind.heartRate,
      value: 72,
      unit: 'bpm',
      status: VitalDisplayStatus.normal,
      history: _hrHistory,
      updatedAt: DateTime.now(),
    ),
    Vital(
      kind: VitalKind.spo2,
      value: 98,
      unit: '%',
      status: VitalDisplayStatus.normal,
      history: _spo2History,
      updatedAt: DateTime.now(),
    ),
    Vital(
      kind: VitalKind.hrv,
      value: 45,
      unit: 'ms',
      status: VitalDisplayStatus.normal,
      history: _hrvHistory,
      updatedAt: DateTime.now(),
    ),
    Vital(
      kind: VitalKind.respiration,
      value: 16,
      unit: '/min',
      status: VitalDisplayStatus.normal,
      history: _respHistory,
      updatedAt: DateTime.now(),
    ),
    Vital(
      kind: VitalKind.activity,
      value: 'Walking',
      unit: '',
      status: VitalDisplayStatus.normal,
      history: _actHistory,
      updatedAt: DateTime.now(),
    ),
    Vital(
      kind: VitalKind.fallDetection,
      value: 'Safe',
      unit: '',
      status: VitalDisplayStatus.normal,
      history: [],
      updatedAt: DateTime.now(),
    ),
  ];

  // Demo scenario: triggers critical vitals for the demo emergency flow
  List<Vital> get criticalScenarioVitals => [
        Vital(
          kind: VitalKind.heartRate,
          value: 142,
          unit: 'bpm',
          status: VitalDisplayStatus.critical,
          history: _hrCriticalHistory,
          updatedAt: DateTime.now(),
        ),
        Vital(
          kind: VitalKind.spo2,
          value: 88,
          unit: '%',
          status: VitalDisplayStatus.critical,
          history: _spo2CriticalHistory,
          updatedAt: DateTime.now(),
        ),
        Vital(
          kind: VitalKind.fallDetection,
          value: 'Fall',
          unit: '',
          status: VitalDisplayStatus.critical,
          history: [],
          updatedAt: DateTime.now(),
        ),
      ];

  Vital? getById(String id) {
    try {
      return _mockVitals.firstWhere((v) => v.routeId == id);
    } catch (_) {
      return null;
    }
  }

  // History data for charts
  static final List<double> _hrHistory = [
    65, 68, 70, 72, 74, 73, 72, 71, 73, 72, 74, 72,
    70, 69, 71, 73, 74, 72, 71, 70, 72, 73, 72, 71,
  ];

  static final List<double> _spo2History = [
    98, 98, 97, 98, 99, 98, 98, 97, 98, 98, 99, 98,
    98, 97, 98, 98, 99, 98, 98, 97, 98, 98, 99, 98,
  ];

  static final List<double> _hrvHistory = [
    42, 44, 45, 47, 45, 43, 44, 46, 45, 44, 45, 46,
    44, 45, 47, 46, 44, 43, 45, 46, 47, 45, 44, 45,
  ];

  static final List<double> _respHistory = [
    16, 15, 16, 17, 16, 15, 16, 16, 17, 16, 15, 16,
    16, 17, 16, 15, 16, 16, 17, 16, 15, 16, 16, 17,
  ];

  static final List<double> _actHistory = [
    0.3, 0.5, 0.6, 0.8, 0.7, 0.6, 0.5, 0.6, 0.7, 0.8,
    0.6, 0.5, 0.4, 0.5, 0.6, 0.7, 0.8, 0.7, 0.6, 0.5,
  ];

  static final List<double> _hrCriticalHistory = [
    72, 80, 95, 110, 125, 135, 140, 142, 141, 143, 142, 144,
  ];

  static final List<double> _spo2CriticalHistory = [
    98, 97, 95, 93, 91, 90, 88, 87, 88, 87, 88, 88,
  ];
}
