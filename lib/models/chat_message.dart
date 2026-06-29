import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, emergency, report, image, document }

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final bool isRead;
  final String? fileUrl;
  final String? fileName;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.isRead = false,
    this.fileUrl,
    this.fileName,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: d['senderId'] as String? ?? d['sender_id'] as String? ?? '',
      receiverId: d['receiverId'] as String? ?? '',
      senderName:
          d['senderName'] as String? ?? d['sender_name'] as String? ?? '',
      content: d['text'] as String? ?? d['content'] as String? ?? '',
      timestamp:
          (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: typeFromString(d['type'] as String? ?? 'text'),
      isRead: d['isRead'] as bool? ?? d['is_read'] as bool? ?? false,
      fileUrl: d['fileUrl'] as String?,
      fileName: d['fileName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'senderId': senderId,
        'receiverId': receiverId,
        'senderName': senderName,
        'text': content,
        'timestamp': Timestamp.fromDate(timestamp),
        'type': typeToString(type),
        'isRead': isRead,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
      };

  static MessageType typeFromString(String s) => switch (s) {
        'emergency' => MessageType.emergency,
        'report' => MessageType.report,
        'image' => MessageType.image,
        'document' => MessageType.document,
        _ => MessageType.text,
      };

  static String typeToString(MessageType t) => switch (t) {
        MessageType.emergency => 'emergency',
        MessageType.report => 'report',
        MessageType.image => 'image',
        MessageType.document => 'document',
        MessageType.text => 'text',
      };
}
