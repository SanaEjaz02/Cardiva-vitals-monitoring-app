import 'package:uuid/uuid.dart';

enum NotifType { alert, health, system }

class AppNotification {
  final String id;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final NotifType type;
  final bool isRead;

  AppNotification({
    String? id,
    required this.title,
    required this.subtitle,
    DateTime? createdAt,
    required this.type,
    this.isRead = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  String get time {
    final h = createdAt.hour;
    final m = createdAt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }

  String get section {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDay =
        DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(notifDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff <= 7) return 'Earlier this week';
    return 'Older';
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        subtitle: subtitle,
        createdAt: createdAt,
        type: type,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'createdAt': createdAt.toIso8601String(),
        'type': type.index,
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String?,
        title: json['title'] as String? ?? '',
        subtitle: (json['subtitle'] ?? json['body'] ?? '') as String,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        type: NotifType.values[(json['type'] as int?) ?? 2],
        isRead: json['isRead'] as bool? ?? false,
      );
}
