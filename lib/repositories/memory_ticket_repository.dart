import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/memory_ticket.dart';

class MemoryTicketRepository {
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;

  MemoryTicketRepository(this._firestore, this._storage);

  Stream<List<MemoryTicket>> watchTickets(String roomId) {
    if (_firestore == null) return Stream.value(const []);
    return _firestore
        .collection('couple_rooms')
        .doc(roomId)
        .collection('memory_tickets')
        .orderBy('memoryDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MemoryTicket.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<List<String>> uploadImages({
    required String roomId,
    required String ticketId,
    required List<XFile> images,
  }) async {
    if (images.isEmpty) return const [];
    if (_storage == null) {
      throw Exception('ไม่สามารถเชื่อมต่อพื้นที่จัดเก็บรูปภาพได้');
    }

    final urls = <String>[];
    try {
      for (final image in images) {
        final bytes = await image.readAsBytes();
        final extension = _fileExtension(image.name);
        final fileId = const Uuid().v4();
        final reference = _storage.ref().child(
              'couple_rooms/$roomId/memory_tickets/$ticketId/$fileId.$extension',
            );
        final task = await reference.putData(
          bytes,
          SettableMetadata(contentType: _contentType(extension)),
        );
        urls.add(await task.ref.getDownloadURL());
      }
      return urls;
    } catch (_) {
      await deleteImages(urls);
      rethrow;
    }
  }

  Future<void> saveTicket(String roomId, MemoryTicket ticket) async {
    if (_firestore == null) {
      throw Exception('ไม่สามารถเชื่อมต่อฐานข้อมูลได้');
    }
    await _firestore
        .collection('couple_rooms')
        .doc(roomId)
        .collection('memory_tickets')
        .doc(ticket.id)
        .set(ticket.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteTicket(String roomId, MemoryTicket ticket) async {
    if (_firestore == null) return;
    await _firestore
        .collection('couple_rooms')
        .doc(roomId)
        .collection('memory_tickets')
        .doc(ticket.id)
        .delete();
    await deleteImages(ticket.imageUrls);
  }

  Future<void> deleteImages(Iterable<String> urls) async {
    if (_storage == null) return;
    for (final url in urls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // The ticket remains usable even if an already-missing file cannot be deleted.
      }
    }
  }

  String _fileExtension(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex < 0) return 'jpg';
    final value = name.substring(dotIndex + 1).toLowerCase();
    return {'jpg', 'jpeg', 'png', 'webp'}.contains(value) ? value : 'jpg';
  }

  String _contentType(String extension) {
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    return 'image/jpeg';
  }
}
