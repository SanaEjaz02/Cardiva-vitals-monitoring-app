import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationsState {
  final List<AppNotification> notifications;
  final Map<NotifType, bool> muted;

  const NotificationsState({
    required this.notifications,
    required this.muted,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    Map<NotifType, bool>? muted,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        muted: muted ?? this.muted,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  static const _storeKey = 'in_app_notifications_v2';
  static const _pendingKey = 'pending_notifications';

  AppNotification? _lastDeleted;
  int _lastDeletedIndex = 0;

  NotificationsNotifier()
      : super(NotificationsState(
          notifications: _defaultSeed(),
          muted: {
            NotifType.alert: false,
            NotifType.health: false,
            NotifType.system: false,
          },
        )) {
    // Wire foreground callback so notification_service can push in-app notifs
    NotificationService.onNewNotification = _addFromService;
    _init();
  }

  @override
  void dispose() {
    NotificationService.onNewNotification = null;
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load persisted notifications (overrides seed)
    final raw = prefs.getString(_storeKey);
    List<AppNotification> loaded = [];
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        loaded = list
            .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    if (loaded.isEmpty) loaded = _defaultSeed();

    // Drain the pending queue written by NotificationService background calls
    final pendingRaw = prefs.getString(_pendingKey);
    if (pendingRaw != null) {
      try {
        final list = jsonDecode(pendingRaw) as List;
        final existing = {for (final n in loaded) n.id};
        for (final j in list.reversed) {
          final n = AppNotification.fromJson(j as Map<String, dynamic>);
          if (!existing.contains(n.id)) {
            loaded.insert(0, n);
            existing.add(n.id);
          }
        }
        await prefs.remove(_pendingKey);
      } catch (_) {}
    }

    loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(notifications: loaded);
    await _save(prefs);
  }

  Future<void> _save([SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(
      _storeKey,
      jsonEncode(state.notifications.map((n) => n.toJson()).toList()),
    );
  }

  void _addFromService(AppNotification notif) => addNotification(notif);

  void addNotification(AppNotification notif) {
    if (state.notifications.any((n) => n.id == notif.id)) return;
    state = state.copyWith(
        notifications: [notif, ...state.notifications]);
    _save();
  }

  void markRead(String id) {
    state = state.copyWith(
      notifications: [
        for (final n in state.notifications)
          if (n.id == id) n.copyWith(isRead: true) else n,
      ],
    );
    _save();
  }

  void markAllRead() {
    state = state.copyWith(
      notifications: [
        for (final n in state.notifications) n.copyWith(isRead: true),
      ],
    );
    _save();
  }

  void delete(String id) {
    final index = state.notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    _lastDeleted = state.notifications[index];
    _lastDeletedIndex = index;
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.id != id).toList(),
    );
    _save();
  }

  void deleteAll() {
    state = state.copyWith(notifications: []);
    _save();
  }

  void undoDelete() {
    final notif = _lastDeleted;
    if (notif == null) return;
    final list = List<AppNotification>.from(state.notifications);
    list.insert(_lastDeletedIndex.clamp(0, list.length), notif);
    _lastDeleted = null;
    state = state.copyWith(notifications: list);
    _save();
  }

  void toggleMuted(NotifType type) {
    final updated = Map<NotifType, bool>.from(state.muted)
      ..[type] = !(state.muted[type] ?? false);
    state = state.copyWith(muted: updated);
  }

  static List<AppNotification> _defaultSeed() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'seed_1',
        title: 'Fall Detected',
        subtitle: 'Auto-alert was sent to 2 contacts',
        createdAt: now.subtract(const Duration(hours: 2)),
        type: NotifType.alert,
      ),
      AppNotification(
        id: 'seed_2',
        title: 'SpO₂ Warning',
        subtitle: 'Dropped to 93% — monitor closely',
        createdAt: now.subtract(const Duration(hours: 3)),
        type: NotifType.health,
      ),
      AppNotification(
        id: 'seed_3',
        title: 'Device Connected',
        subtitle: 'Cardiva Band 1 synced successfully',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        type: NotifType.system,
        isRead: true,
      ),
      AppNotification(
        id: 'seed_4',
        title: 'Weekly Report Ready',
        subtitle: 'Your weekly health summary is available',
        createdAt: now.subtract(const Duration(days: 1, hours: 5)),
        type: NotifType.health,
        isRead: true,
      ),
      AppNotification(
        id: 'seed_5',
        title: 'Heart Rate Alert',
        subtitle: 'Resting HR above 100 bpm',
        createdAt: now.subtract(const Duration(days: 5)),
        type: NotifType.alert,
        isRead: true,
      ),
    ];
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(),
);
