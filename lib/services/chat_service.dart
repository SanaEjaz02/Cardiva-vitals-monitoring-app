import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

/// Firestore layout (matches the project's canonical schema):
///
///   /chats/{chatId}
///     patientId   : String
///     guardianId  : String
///     participants: [patientId, guardianId]   ← for arrayContains queries
///     lastMessage      : String
///     lastMessageTime  : Timestamp
///     lastSenderId     : String
///     lastType         : String
///
///   /chats/{chatId}/messages/{msgId}
///     senderId   : String
///     receiverId : String
///     senderName : String
///     text       : String
///     timestamp  : Timestamp
///     type       : String
///     isRead     : bool
///
/// chatId is always [patientUid, guardianUid].sorted().join('_').
class ChatService {
  ChatService._();

  static final _db = FirebaseFirestore.instance;

  // ── Chat ID ──────────────────────────────────────────────────────────────

  static String chatId(String patientUid, String guardianUid) {
    final sorted = [patientUid, guardianUid]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Send a message ───────────────────────────────────────────────────────

  static Future<void> sendMessage({
    required String patientUid,
    required String guardianUid,
    required String senderUid,
    required String senderName,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    final cid = chatId(patientUid, guardianUid);
    final receiverUid = senderUid == patientUid ? guardianUid : patientUid;
    final now = DateTime.now();

    final chatRef = _db.collection('chats').doc(cid);
    final msgRef = chatRef.collection('messages').doc();

    final msg = ChatMessage(
      id: '',
      senderId: senderUid,
      receiverId: receiverUid,
      senderName: senderName,
      content: text,
      timestamp: now,
      type: type,
    );

    // Step 1: Create/update the chat document FIRST.
    // This must be a separate write before the message because Firestore
    // security rules evaluate get() calls against the pre-write state.
    // If we batch both together, the message rule's get(chatDoc) sees no
    // document yet and denies the write.
    await chatRef.set(
      {
        'patientId': patientUid,
        'guardianId': guardianUid,
        'participants': [patientUid, guardianUid],
        'lastMessage': text,
        'lastMessageTime': Timestamp.fromDate(now),
        'lastSenderId': senderUid,
        'lastSenderName': senderName,
        'lastType': ChatMessage.typeToString(type),
      },
      SetOptions(merge: true),
    );

    // Step 2: Now write the message — the chat doc exists so get() works.
    await msgRef.set(msg.toFirestore());
  }

  // ── Stream messages ──────────────────────────────────────────────────────

  static Stream<List<ChatMessage>> messagesStream(
      String patientUid, String guardianUid) {
    return _db
        .collection('chats')
        .doc(chatId(patientUid, guardianUid))
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());
  }

  // ── Stream chat list for a user ──────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> chatListStream(String uid) {
    // No orderBy — sort client-side to avoid requiring a composite Firestore index.
    // arrayContains alone uses an auto-single-field index that Firestore creates
    // automatically.
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((s) {
      final docs = s.docs.map((d) {
        final data = d.data();
        data['chat_id'] = d.id;
        return data;
      }).toList();
      docs.sort((a, b) {
        final aTime = a['lastMessageTime'] as Timestamp?;
        final bTime = b['lastMessageTime'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return docs;
    });
  }

  // ── Mark messages read ───────────────────────────────────────────────────

  static Future<void> markRead(String myUid, String otherUid) async {
    final cid = chatId(myUid, otherUid);
    final chatRef = _db.collection('chats').doc(cid);

    // Single-field filter — no composite Firestore index required.
    final snap = await chatRef
        .collection('messages')
        .where('receiverId', isEqualTo: myUid)
        .get();

    final unread = snap.docs.where((d) => d.data()['isRead'] != true).toList();

    final batch = _db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'isRead': true});
    }
    // Store read-at timestamp on the chat doc for total-unread tracking
    batch.set(chatRef, {'${myUid}_read_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
    if (unread.isNotEmpty) {
      await batch.commit();
    } else {
      await chatRef.set({'${myUid}_read_at': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    }
  }

  // ── Delete a message ─────────────────────────────────────────────────────

  static Future<void> deleteMessage(
      String uid1, String uid2, String messageId) async {
    await _db
        .collection('chats')
        .doc(chatId(uid1, uid2))
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // ── Per-conversation unread count ─────────────────────────────────────────
  // Single-field filter avoids requiring a composite Firestore index.
  // isRead is checked client-side.

  static Stream<int> unreadCountStream(String myUid, String otherUid) {
    return _db
        .collection('chats')
        .doc(chatId(myUid, otherUid))
        .collection('messages')
        .where('receiverId', isEqualTo: myUid)
        .snapshots()
        .map((s) =>
            s.docs.where((d) => d.data()['isRead'] != true).length);
  }

  // ── Total unread across ALL conversations for a user ──────────────────────
  // Uses the {uid}_read_at field written by markRead() to avoid extra reads.
  static Stream<int> totalUnreadStream(String myUid) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) {
      int count = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final lastSenderId = data['lastSenderId'] as String?;
        if (lastSenderId == null || lastSenderId == myUid) continue;
        final lastMsgTime = data['lastMessageTime'] as Timestamp?;
        final readAt = data['${myUid}_read_at'] as Timestamp?;
        if (readAt == null ||
            (lastMsgTime != null && lastMsgTime.compareTo(readAt) > 0)) {
          count++;
        }
      }
      return count;
    });
  }
}
