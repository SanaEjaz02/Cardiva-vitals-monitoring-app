import 'package:cloud_firestore/cloud_firestore.dart';

class InAppMessage {
  final String id;
  final String fromUid;
  final String fromName;
  // 'fall' | 'lowSpo2' | 'highHr' | 'manual' | 'report'
  final String type;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  const InAppMessage({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.type,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  factory InAppMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InAppMessage(
      id: doc.id,
      fromUid: d['from_uid'] as String? ?? '',
      fromName: d['from_name'] as String? ?? 'Patient',
      type: d['type'] as String? ?? 'manual',
      content: d['content'] as String? ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: d['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'from_uid': fromUid,
        'from_name': fromName,
        'type': type,
        'content': content,
        'timestamp': Timestamp.fromDate(timestamp),
        'is_read': isRead,
      };

  String get typeLabel => switch (type) {
        'fall'    => 'Fall Detected',
        'lowSpo2' => 'Low SpO₂ Alert',
        'highHr'  => 'High Heart Rate',
        'manual'  => 'SOS Alert',
        'report'  => 'Health Report',
        _         => 'Alert',
      };
}
