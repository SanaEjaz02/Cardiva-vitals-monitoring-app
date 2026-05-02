import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  final ThemeMode themeMode;
  final bool emergencyAlertsEnabled;
  final bool warningAlertsEnabled;
  final bool vitalMonitoringEnabled;
  final bool locationEnabled;
  final bool dataCollectionEnabled;
  final bool biometricLockEnabled;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.emergencyAlertsEnabled = true,
    this.warningAlertsEnabled = true,
    this.vitalMonitoringEnabled = true,
    this.locationEnabled = true,
    this.dataCollectionEnabled = true,
    this.biometricLockEnabled = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? emergencyAlertsEnabled,
    bool? warningAlertsEnabled,
    bool? vitalMonitoringEnabled,
    bool? locationEnabled,
    bool? dataCollectionEnabled,
    bool? biometricLockEnabled,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        emergencyAlertsEnabled:
            emergencyAlertsEnabled ?? this.emergencyAlertsEnabled,
        warningAlertsEnabled: warningAlertsEnabled ?? this.warningAlertsEnabled,
        vitalMonitoringEnabled:
            vitalMonitoringEnabled ?? this.vitalMonitoringEnabled,
        locationEnabled: locationEnabled ?? this.locationEnabled,
        dataCollectionEnabled:
            dataCollectionEnabled ?? this.dataCollectionEnabled,
        biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void toggleDarkMode(bool isDark) => state = state.copyWith(
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      );

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  void setEmergencyAlerts(bool v) =>
      state = state.copyWith(emergencyAlertsEnabled: v);

  void setWarningAlerts(bool v) =>
      state = state.copyWith(warningAlertsEnabled: v);

  void setVitalMonitoring(bool v) =>
      state = state.copyWith(vitalMonitoringEnabled: v);

  void setLocation(bool v) => state = state.copyWith(locationEnabled: v);

  void setDataCollection(bool v) =>
      state = state.copyWith(dataCollectionEnabled: v);

  void setBiometricLock(bool v) =>
      state = state.copyWith(biometricLockEnabled: v);
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
