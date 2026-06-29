import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';

/// SQLite cache for chat messages.
/// Loaded immediately on screen open (no network needed).
/// Firestore stream writes here on every update.
/// Deletes are instant and permanent locally.
class LocalChatDb {
  LocalChatDb._();
  static final LocalChatDb instance = LocalChatDb._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'cardiva_chat.db'),
      version: 2,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE messages (
          id          TEXT PRIMARY KEY,
          chat_id     TEXT NOT NULL,
          sender_id   TEXT NOT NULL,
          receiver_id TEXT NOT NULL,
          sender_name TEXT NOT NULL,
          content     TEXT NOT NULL,
          timestamp   INTEGER NOT NULL,
          type        TEXT NOT NULL,
          is_read     INTEGER NOT NULL DEFAULT 0,
          file_url    TEXT,
          file_name   TEXT
        )
      '''),
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN file_url TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN file_name TEXT');
        }
      },
    );
    return _db!;
  }

  /// Load cached messages for a chat, oldest first.
  Future<List<ChatMessage>> loadMessages(String chatId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_rowToMessage).toList();
  }

  /// Upsert a batch of messages (called on every Firestore stream event).
  Future<void> saveMessages(String chatId, List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    for (final m in messages) {
      batch.insert(
        'messages',
        _messageToRow(chatId, m),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Delete a single message permanently from local cache.
  Future<void> deleteMessage(String chatId, String messageId) async {
    final db = await _database;
    await db.delete(
      'messages',
      where: 'chat_id = ? AND id = ?',
      whereArgs: [chatId, messageId],
    );
  }

  /// Delete all locally cached messages for a chat.
  Future<void> clearChat(String chatId) async {
    final db = await _database;
    await db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
  }

  /// Wipe the entire local cache on logout (prevents data leaking to next user).
  Future<void> clearAll() async {
    final db = await _database;
    await db.delete('messages');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _messageToRow(String chatId, ChatMessage m) => {
        'id': m.id,
        'chat_id': chatId,
        'sender_id': m.senderId,
        'receiver_id': m.receiverId,
        'sender_name': m.senderName,
        'content': m.content,
        'timestamp': m.timestamp.millisecondsSinceEpoch,
        'type': ChatMessage.typeToString(m.type),
        'is_read': m.isRead ? 1 : 0,
        'file_url': m.fileUrl,
        'file_name': m.fileName,
      };

  ChatMessage _rowToMessage(Map<String, dynamic> row) => ChatMessage(
        id: row['id'] as String,
        senderId: row['sender_id'] as String,
        receiverId: row['receiver_id'] as String,
        senderName: row['sender_name'] as String,
        content: row['content'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        type: ChatMessage.typeFromString(row['type'] as String),
        isRead: (row['is_read'] as int) == 1,
        fileUrl: row['file_url'] as String?,
        fileName: row['file_name'] as String?,
      );
}
