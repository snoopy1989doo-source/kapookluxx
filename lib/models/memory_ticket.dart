import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryTicket {
  final String id;
  final String title;
  final String note;
  final String? location;
  final DateTime memoryDate;
  final String categoryKey;
  final String emoji;
  final String colorHex;
  final List<String> imageUrls;
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryTicket({
    required this.id,
    required this.title,
    this.note = '',
    this.location,
    required this.memoryDate,
    required this.categoryKey,
    required this.emoji,
    required this.colorHex,
    this.imageUrls = const [],
    required this.createdByUserId,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  MemoryTicket copyWith({
    String? title,
    String? note,
    String? location,
    DateTime? memoryDate,
    String? categoryKey,
    String? emoji,
    String? colorHex,
    List<String>? imageUrls,
    String? createdByUserId,
    String? createdByName,
    DateTime? updatedAt,
  }) {
    return MemoryTicket(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      location: location ?? this.location,
      memoryDate: memoryDate ?? this.memoryDate,
      categoryKey: categoryKey ?? this.categoryKey,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      imageUrls: imageUrls ?? this.imageUrls,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'note': note,
      'location': location,
      'memoryDate': Timestamp.fromDate(memoryDate),
      'categoryKey': categoryKey,
      'emoji': emoji,
      'colorHex': colorHex,
      'imageUrls': imageUrls,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MemoryTicket.fromMap(Map<String, dynamic> map, String id) {
    return MemoryTicket(
      id: id,
      title: map['title'] as String? ?? 'ความทรงจำของเรา',
      note: map['note'] as String? ?? '',
      location: map['location'] as String?,
      memoryDate: _parseDate(map['memoryDate']),
      categoryKey: map['categoryKey'] as String? ?? 'activity',
      emoji: map['emoji'] as String? ?? '💕',
      colorHex: map['colorHex'] as String? ?? '#E91E63',
      imageUrls:
          (map['imageUrls'] as List? ?? const []).whereType<String>().toList(),
      createdByUserId: map['createdByUserId'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? 'สมาชิก',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
