enum NotifType { alert, health, system }

class AppNotification {
  final String id;
  final String section;
  final String title;
  final String subtitle;
  final String time;
  final NotifType type;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        section: section,
        title: title,
        subtitle: subtitle,
        time: time,
        type: type,
        isRead: isRead ?? this.isRead,
      );
}
