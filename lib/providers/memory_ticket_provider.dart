import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/memory_ticket.dart';
import '../repositories/memory_ticket_repository.dart';
import 'auth_provider.dart';
import 'couple_provider.dart';

final memoryTicketRepositoryProvider = Provider<MemoryTicketRepository>((ref) {
  FirebaseStorage? storage;
  try {
    storage = Firebase.apps.isNotEmpty ? FirebaseStorage.instance : null;
  } catch (_) {
    storage = null;
  }
  return MemoryTicketRepository(ref.watch(firestoreProvider), storage);
});

final memoryTicketsProvider = StreamProvider<List<MemoryTicket>>((ref) {
  final roomId = ref.watch(coupleRoomIdProvider);
  if (roomId == null || roomId.isEmpty) return Stream.value(const []);
  return ref.watch(memoryTicketRepositoryProvider).watchTickets(roomId);
});
