import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:expense_tracker/core/constants/memory_ticket_options.dart';
import 'package:expense_tracker/models/memory_ticket.dart';
import 'package:expense_tracker/screens/memory/memory_ticket_form_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH', null);
  });

  test('MemoryTicket keeps shared memory fields through Firestore mapping', () {
    final date = DateTime(2026, 9, 19, 18, 30);
    final ticket = MemoryTicket(
      id: 'memory-1',
      title: 'ดูหนังด้วยกัน',
      note: 'หนังสนุกและป๊อปคอร์นอร่อย',
      location: 'Cinema One',
      memoryDate: date,
      categoryKey: 'movie',
      emoji: '🎬',
      colorHex: '#7C5CE7',
      imageUrls: const ['https://example.com/one.jpg'],
      createdByUserId: 'user-1',
      createdByName: 'ต๋อง',
      createdAt: date,
      updatedAt: date,
    );

    final restored = MemoryTicket.fromMap(ticket.toMap(), ticket.id);

    expect(restored.id, 'memory-1');
    expect(restored.title, 'ดูหนังด้วยกัน');
    expect(restored.memoryDate, date);
    expect(restored.categoryKey, 'movie');
    expect(restored.imageUrls, ['https://example.com/one.jpg']);
    expect(restored.createdByName, 'ต๋อง');
  });

  test('unknown memory category falls back to activity', () {
    final category = memoryTicketCategoryFor('unknown');

    expect(category.key, 'activity');
    expect(category.label, 'กิจกรรม');
  });

  testWidgets('memory ticket form fits a narrow mobile viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MemoryTicketFormScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('สร้าง Memory Ticket'), findsOneWidget);
    expect(find.text('บันทึก Memory Ticket'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
