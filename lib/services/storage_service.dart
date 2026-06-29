import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class StorageService {
  StorageService._();

  static FirebaseStorage get _storage => FirebaseStorage.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Uploads a report PDF and returns the public download URL, or null on failure.
  static Future<String?> uploadReportPdf(String reportId, File file) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = _storage.ref('users/$uid/reports/$reportId.pdf');
      final task = await ref.putFile(
        file,
        SettableMetadata(contentType: 'application/pdf'),
      );
      return await task.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Deletes a report PDF from Storage. Silent on failure (file may not exist).
  static Future<void> deleteReportPdf(String reportId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _storage.ref('users/$uid/reports/$reportId.pdf').delete();
    } catch (_) {}
  }

  /// Uploads a chat attachment and returns its download URL, or null on failure.
  /// [chatId] — the sorted UID chat document ID.
  /// [file] — local file to upload.
  /// [contentType] — MIME type (e.g. 'image/jpeg', 'application/pdf').
  static Future<String?> uploadChatFile(
    String chatId,
    File file,
    String contentType,
  ) async {
    try {
      final ext = file.path.split('.').last;
      final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref('chats/$chatId/$name');
      final task = await ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
      return await task.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Uploads the user's profile photo and returns its download URL, or null on failure.
  static Future<String?> uploadProfilePhoto(File file) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = _storage.ref('users/$uid/profile/avatar.jpg');
      final task = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await task.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Opens a Storage download URL in the external browser/PDF viewer.
  static Future<void> openDownloadUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
