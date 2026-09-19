import 'package:flutter/material.dart';

class MemoryTicketCategory {
  final String key;
  final String label;
  final String emoji;
  final IconData icon;

  const MemoryTicketCategory({
    required this.key,
    required this.label,
    required this.emoji,
    required this.icon,
  });
}

const memoryTicketCategories = <MemoryTicketCategory>[
  MemoryTicketCategory(
    key: 'movie',
    label: 'ดูหนัง',
    emoji: '🎬',
    icon: Icons.movie_outlined,
  ),
  MemoryTicketCategory(
    key: 'travel',
    label: 'ท่องเที่ยว',
    emoji: '✈️',
    icon: Icons.flight_takeoff_rounded,
  ),
  MemoryTicketCategory(
    key: 'food',
    label: 'ร้านอาหาร',
    emoji: '🍜',
    icon: Icons.restaurant_outlined,
  ),
  MemoryTicketCategory(
    key: 'activity',
    label: 'กิจกรรม',
    emoji: '🎡',
    icon: Icons.local_activity_outlined,
  ),
  MemoryTicketCategory(
    key: 'special',
    label: 'วันพิเศษ',
    emoji: '🎉',
    icon: Icons.celebration_outlined,
  ),
];

const memoryTicketEmojis = <String>[
  '💕',
  '🎬',
  '✈️',
  '🎡',
  '🍜',
  '🎉',
  '🏕️',
  '📸',
  '🌅',
  '🎂',
];

const memoryTicketColors = <Color>[
  Color(0xFFE91E63),
  Color(0xFFFF7A73),
  Color(0xFF7C5CE7),
  Color(0xFF3182CE),
  Color(0xFF14A38B),
  Color(0xFFF59E0B),
];

MemoryTicketCategory memoryTicketCategoryFor(String key) {
  return memoryTicketCategories.firstWhere(
    (category) => category.key == key,
    orElse: () => memoryTicketCategories[3],
  );
}
