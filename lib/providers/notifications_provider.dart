import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';

class NotificationsState {
  final List<AppNotification> notifications;
  final Map<NotifType, bool> muted;

  const NotificationsState({
    required this.notifications,
    required this.muted,
  });

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
  AppNotification? _lastDeleted;
  int _lastDeletedIndex = 0;

  NotificationsNotifier()
      : super(NotificationsState(
          notifications: _seed,
          muted: {
            NotifType.alert: false,
            NotifType.health: false,
            NotifType.system: false,
          },
        ));

  static final _seed = <AppNotification>[
    const AppNotification(
      id: '1',
      section: 'Today',
      title: 'Fall Detected',
      subtitle: 'Auto-alert was sent to 2 contacts',
      time: '10:15 AM',
      type: NotifType.alert,
    ),
    const AppNotification(
      id: '2',
      section: 'Today',
      title: 'SpO₂ Warning',
      subtitle: 'Dropped to 93% — 10:02 AM',
      time: '10:02 AM',
      type: NotifType.health,
    ),
    const AppNotification(
      id: '3',
      section: 'Yesterday',
      title: 'Device Connected',
      subtitle: 'Cardiva Band 1 synced',
      time: '9:30 AM',
      type: NotifType.system,
      isRead: true,
    ),
    const AppNotification(
      id: '4',
      section: 'Yesterday',
      title: 'Weekly Report Ready',
      subtitle: 'Apr 19–25 summary available',
      time: '8:00 AM',
      type: NotifType.health,
      isRead: true,
    ),
    const AppNotification(
      id: '5',
      section: 'Earlier this week',
      title: 'Heart Rate Alert',
      subtitle: 'Resting HR above 100 bpm',
      time: 'Mon 2:10 PM',
      type: NotifType.alert,
      isRead: true,
    ),
  ];

  void markRead(String id) {
    state = state.copyWith(
      notifications: [
        for (final n in state.notifications)
          if (n.id == id) n.copyWith(isRead: true) else n,
      ],
    );
  }

  void markAllRead() {
    state = state.copyWith(
      notifications: [
        for (final n in state.notifications) n.copyWith(isRead: true),
      ],
    );
  }

  void delete(String id) {
    final index = state.notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    _lastDeleted = state.notifications[index];
    _lastDeletedIndex = index;
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.id != id).toList(),
    );
  }

  void undoDelete() {
    final notif = _lastDeleted;
    if (notif == null) return;
    final list = List<AppNotification>.from(state.notifications);
    list.insert(_lastDeletedIndex.clamp(0, list.length), notif);
    _lastDeleted = null;
    state = state.copyWith(notifications: list);
  }

  void toggleMuted(NotifType type) {
    final updated = Map<NotifType, bool>.from(state.muted)
      ..[type] = !(state.muted[type] ?? false);
    state = state.copyWith(muted: updated);
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(),
);
