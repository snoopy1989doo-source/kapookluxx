import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MerchantSample {
  final String mainCategoryId;
  final String? subCategoryId;
  final String? walletId;
  final DateTime recordedAt;

  const MerchantSample({
    required this.mainCategoryId,
    this.subCategoryId,
    this.walletId,
    required this.recordedAt,
  });

  String get signature =>
      '$mainCategoryId|${subCategoryId ?? ''}|${walletId ?? ''}';

  Map<String, dynamic> toLocalMap() => {
        'mainCategoryId': mainCategoryId,
        'subCategoryId': subCategoryId,
        'walletId': walletId,
        'recordedAt': recordedAt.toIso8601String(),
      };

  Map<String, dynamic> toFirestoreMap() => {
        'mainCategoryId': mainCategoryId,
        'subCategoryId': subCategoryId,
        'walletId': walletId,
        'recordedAt': Timestamp.fromDate(recordedAt),
      };

  factory MerchantSample.fromMap(Map<String, dynamic> map) {
    return MerchantSample(
      mainCategoryId: map['mainCategoryId']?.toString() ?? '',
      subCategoryId: _optionalString(map['subCategoryId']),
      walletId: _optionalString(map['walletId']),
      recordedAt: _readDate(map['recordedAt'] ?? map['lastUpdated']),
    );
  }
}

class MerchantMemory {
  static const maxSamples = 5;

  final String name;
  final String mainCategoryId;
  final String? subCategoryId;
  final String? walletId;
  final int count;
  final DateTime lastUpdated;
  final List<MerchantSample> samples;

  const MerchantMemory({
    required this.name,
    required this.mainCategoryId,
    this.subCategoryId,
    this.walletId,
    this.count = 1,
    required this.lastUpdated,
    this.samples = const [],
  });

  factory MerchantMemory.fromSamples({
    required String name,
    required List<MerchantSample> samples,
    DateTime? lastUpdated,
  }) {
    final recentSamples = samples
        .where((sample) => sample.mainCategoryId.isNotEmpty)
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final capped = recentSamples.length > maxSamples
        ? recentSamples.sublist(recentSamples.length - maxSamples)
        : recentSamples;

    if (capped.isEmpty) {
      return MerchantMemory(
        name: name,
        mainCategoryId: '',
        count: 0,
        lastUpdated: lastUpdated ?? DateTime.now(),
      );
    }

    final totals = <String, int>{};
    for (final sample in capped) {
      totals[sample.signature] = (totals[sample.signature] ?? 0) + 1;
    }

    // A tie is resolved by the most recent choice, so user corrections take effect.
    MerchantSample preferred = capped.last;
    var preferredCount = totals[preferred.signature] ?? 0;
    for (final sample in capped.reversed) {
      final sampleCount = totals[sample.signature] ?? 0;
      if (sampleCount > preferredCount) {
        preferred = sample;
        preferredCount = sampleCount;
      }
    }

    return MerchantMemory(
      name: name,
      mainCategoryId: preferred.mainCategoryId,
      subCategoryId: preferred.subCategoryId,
      walletId: preferred.walletId,
      count: capped.length,
      lastUpdated: lastUpdated ?? capped.last.recordedAt,
      samples: List.unmodifiable(capped),
    );
  }

  MerchantMemory record(MerchantSample sample, {String? merchantName}) {
    return MerchantMemory.fromSamples(
      name: merchantName ?? name,
      samples: [...samples, sample],
      lastUpdated: sample.recordedAt,
    );
  }

  Map<String, dynamic> toLocalMap() => {
        'name': name,
        'mainCategoryId': mainCategoryId,
        'subCategoryId': subCategoryId,
        'walletId': walletId,
        'count': count,
        'lastUpdated': lastUpdated.toIso8601String(),
        'samples': samples.map((sample) => sample.toLocalMap()).toList(),
      };

  Map<String, dynamic> toFirestoreMap() => {
        'name': name,
        'mainCategoryId': mainCategoryId,
        'subCategoryId': subCategoryId,
        'walletId': walletId,
        'count': count,
        'lastUpdated': Timestamp.fromDate(lastUpdated),
        'samples': samples.map((sample) => sample.toFirestoreMap()).toList(),
      };

  factory MerchantMemory.fromMap(Map<String, dynamic> map) {
    final rawSamples = map['samples'];
    final samples = <MerchantSample>[];
    if (rawSamples is List) {
      for (final value in rawSamples) {
        if (value is Map) {
          samples.add(MerchantSample.fromMap(Map<String, dynamic>.from(value)));
        }
      }
    }

    // Convert the old single-value format into the new rolling history.
    if (samples.isEmpty &&
        (map['mainCategoryId']?.toString() ?? '').isNotEmpty) {
      samples.add(
        MerchantSample(
          mainCategoryId: map['mainCategoryId'].toString(),
          subCategoryId: _optionalString(map['subCategoryId']),
          walletId: _optionalString(map['walletId']),
          recordedAt: _readDate(map['lastUpdated']),
        ),
      );
    }

    return MerchantMemory.fromSamples(
      name: map['name']?.toString() ?? '',
      samples: samples,
      lastUpdated: _readDate(map['lastUpdated']),
    );
  }
}

class MerchantLearningService {
  static const String _prefKey = 'merchant_memory_cache_v2';
  static const String _legacyPrefKey = 'ai_merchant_memory_cache_v1';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<MerchantMemory?> predictCategory({
    required String receiverOrMerchantName,
    String? householdId,
  }) async {
    final cleanName = _cleanKey(receiverOrMerchantName);
    if (cleanName.length < 2) return null;

    MerchantMemory? localMemory;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = await _readCache(prefs, householdId);
      final localEntry = _findCacheEntry(cache, cleanName);
      if (localEntry != null) {
        localMemory = MerchantMemory.fromMap(localEntry);
      }

      if (householdId != null && householdId.isNotEmpty) {
        final newDoc = await _firestore
            .collection('couple_rooms')
            .doc(householdId)
            .collection('merchant_memory')
            .doc(cleanName)
            .get()
            .timeout(const Duration(seconds: 2));

        MerchantMemory? cloudMemory;
        if (newDoc.exists && newDoc.data() != null) {
          cloudMemory = MerchantMemory.fromMap(newDoc.data()!);
        } else {
          // One-time compatibility read for data written by the old implementation.
          final legacyDoc = await _firestore
              .collection('households')
              .doc(householdId)
              .collection('ai_merchant_memory')
              .doc(cleanName)
              .get()
              .timeout(const Duration(seconds: 2));
          if (legacyDoc.exists && legacyDoc.data() != null) {
            cloudMemory = MerchantMemory.fromMap(legacyDoc.data()!);
            await _memoryDocument(householdId, cleanName)
                .set(cloudMemory.toFirestoreMap(), SetOptions(merge: true));
          }
        }

        if (cloudMemory != null &&
            (localMemory == null ||
                cloudMemory.lastUpdated.isAfter(localMemory.lastUpdated))) {
          localMemory = cloudMemory;
          cache[cleanName] = cloudMemory.toLocalMap();
          await _writeCache(prefs, householdId, cache);
        }
      }
    } catch (error) {
      debugPrint('Merchant memory lookup notice: $error');
    }
    return localMemory;
  }

  static Future<void> learnMerchantCategory({
    required String receiverOrMerchantName,
    required String mainCategoryId,
    String? subCategoryId,
    String? walletId,
    String? householdId,
  }) async {
    final cleanName = _cleanKey(receiverOrMerchantName);
    if (cleanName.length < 2 || mainCategoryId.isEmpty) return;

    final merchantName = receiverOrMerchantName.trim();
    final sample = MerchantSample(
      mainCategoryId: mainCategoryId,
      subCategoryId: subCategoryId,
      walletId: walletId,
      recordedAt: DateTime.now(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = await _readCache(prefs, householdId);
      final existingData = cache[cleanName];
      final existing = existingData is Map
          ? MerchantMemory.fromMap(Map<String, dynamic>.from(existingData))
          : MerchantMemory.fromSamples(name: merchantName, samples: const []);
      final localMemory = existing.record(sample, merchantName: merchantName);
      cache[cleanName] = localMemory.toLocalMap();
      await _writeCache(prefs, householdId, cache);

      if (householdId != null && householdId.isNotEmpty) {
        final document = _memoryDocument(householdId, cleanName);
        final cloudMemory = await _firestore
            .runTransaction<MerchantMemory>((transaction) async {
          final snapshot = await transaction.get(document);
          final current = snapshot.exists && snapshot.data() != null
              ? MerchantMemory.fromMap(snapshot.data()!)
              : MerchantMemory.fromSamples(
                  name: merchantName, samples: const []);
          final updated = current.record(sample, merchantName: merchantName);
          transaction.set(
              document, updated.toFirestoreMap(), SetOptions(merge: true));
          return updated;
        });

        cache[cleanName] = cloudMemory.toLocalMap();
        await _writeCache(prefs, householdId, cache);
      }
    } catch (error) {
      // Local memory is already saved before cloud sync, so OCR remains useful offline.
      debugPrint('Merchant memory save notice: $error');
    }
  }

  static DocumentReference<Map<String, dynamic>> _memoryDocument(
    String householdId,
    String cleanName,
  ) {
    return _firestore
        .collection('couple_rooms')
        .doc(householdId)
        .collection('merchant_memory')
        .doc(cleanName);
  }

  static Future<Map<String, dynamic>> _readCache(
    SharedPreferences prefs,
    String? householdId,
  ) async {
    final key = _cacheKey(householdId);
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }

    // Local users keep their old learned entries after the data-format upgrade.
    final legacyRaw = prefs.getString(_legacyPrefKey);
    if (legacyRaw != null) {
      try {
        final legacy = Map<String, dynamic>.from(jsonDecode(legacyRaw));
        await _writeCache(prefs, householdId, legacy);
        return legacy;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static Future<void> _writeCache(
    SharedPreferences prefs,
    String? householdId,
    Map<String, dynamic> cache,
  ) {
    return prefs.setString(_cacheKey(householdId), jsonEncode(cache));
  }

  static String _cacheKey(String? householdId) =>
      '${_prefKey}_${householdId == null || householdId.isEmpty ? 'local' : householdId}';

  static Map<String, dynamic>? _findCacheEntry(
    Map<String, dynamic> cache,
    String cleanName,
  ) {
    final exact = cache[cleanName];
    if (exact is Map) return Map<String, dynamic>.from(exact);

    final matches = cache.entries
        .where((entry) => _matchName(cleanName, entry.key))
        .toList();
    if (matches.length != 1 || matches.single.value is! Map) return null;
    return Map<String, dynamic>.from(matches.single.value as Map);
  }

  static String _cleanKey(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\sก-๙]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase()
        .trim();
  }

  static bool _matchName(String query, String target) {
    final q = query.toLowerCase();
    final t = target.toLowerCase();
    return q.contains(t) || t.contains(q);
  }
}

String? _optionalString(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
