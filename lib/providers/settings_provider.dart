import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SharedPreferences keys for report time — also read by background isolate
const kReportHourKey = 'daily_report_hour';
const kReportMinuteKey = 'daily_report_minute';
const kLastReportDayKey = 'last_daily_report_day';

class AppSettings {
  final ThemeMode themeMode;
  final bool emergencyAlertsEnabled;
  final bool warningAlertsEnabled;
  final bool vitalMonitoringEnabled;
  final bool locationEnabled;
  final bool dataCollectionEnabled;
  final bool biometricLockEnabled;
  // Daily report scheduled time (default 22:00 / 10 PM)
  final int dailyReportHour;
  final int dailyReportMinute;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.emergencyAlertsEnabled = true,
    this.warningAlertsEnabled = true,
    this.vitalMonitoringEnabled = true,
    this.locationEnabled = true,
    this.dataCollectionEnabled = true,
    this.biometricLockEnabled = false,
    this.dailyReportHour = 22,
    this.dailyReportMinute = 0,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? emergencyAlertsEnabled,
    bool? warningAlertsEnabled,
    bool? vitalMonitoringEnabled,
    bool? locationEnabled,
    bool? dataCollectionEnabled,
    bool? biometricLockEnabled,
    int? dailyReportHour,
    int? dailyReportMinute,
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
        dailyReportHour: dailyReportHour ?? this.dailyReportHour,
        dailyReportMinute: dailyReportMinute ?? this.dailyReportMinute,
      );

  TimeOfDay get reportTime =>
      TimeOfDay(hour: dailyReportHour, minute: dailyReportMinute);

  String get reportTimeLabel =>
      '${dailyReportHour.toString().padLeft(2, '0')}:'
      '${dailyReportMinute.toString().padLeft(2, '0')}';
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(kReportHourKey) ?? 22;
    final minute = prefs.getInt(kReportMinuteKey) ?? 0;
    state = state.copyWith(dailyReportHour: hour, dailyReportMinute: minute);
  }

  Future<void> setDailyReportTime(int hour, int minute) async {
    state = state.copyWith(dailyReportHour: hour, dailyReportMinute: minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kReportHourKey, hour);
    await prefs.setInt(kReportMinuteKey, minute);
  }

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
