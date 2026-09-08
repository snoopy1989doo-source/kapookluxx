import 'package:expense_tracker/services/merchant_learning_service.dart';
import 'package:flutter_test/flutter_test.dart';

MerchantSample sample(
  int minute,
  String category, {
  String? subCategory,
  String? wallet,
}) {
  return MerchantSample(
    mainCategoryId: category,
    subCategoryId: subCategory,
    walletId: wallet,
    recordedAt: DateTime(2026, 9, 9, 10, minute),
  );
}

void main() {
  group('MerchantMemory', () {
    test('keeps only the five latest samples', () {
      var memory =
          MerchantMemory.fromSamples(name: 'ร้านพี่อ๋อ', samples: const []);

      for (var index = 0; index < 6; index++) {
        memory = memory.record(sample(index, 'category-$index'));
      }

      expect(memory.count, MerchantMemory.maxSamples);
      expect(memory.samples.map((item) => item.mainCategoryId), [
        'category-1',
        'category-2',
        'category-3',
        'category-4',
        'category-5',
      ]);
    });

    test('predicts the most frequently used complete selection', () {
      final memory = MerchantMemory.fromSamples(
        name: 'ร้านพี่อ๋อ',
        samples: [
          sample(1, 'living', subCategory: 'snack', wallet: 'cash'),
          sample(2, 'shopping', subCategory: 'gift', wallet: 'bank'),
          sample(3, 'living', subCategory: 'snack', wallet: 'cash'),
          sample(4, 'shopping', subCategory: 'gift', wallet: 'bank'),
          sample(5, 'living', subCategory: 'snack', wallet: 'cash'),
        ],
      );

      expect(memory.mainCategoryId, 'living');
      expect(memory.subCategoryId, 'snack');
      expect(memory.walletId, 'cash');
    });

    test('uses the latest selection when frequencies are tied', () {
      final memory = MerchantMemory.fromSamples(
        name: 'ร้านพี่อ๋อ',
        samples: [
          sample(1, 'living', wallet: 'cash'),
          sample(2, 'shopping', wallet: 'bank'),
        ],
      );

      expect(memory.mainCategoryId, 'shopping');
      expect(memory.walletId, 'bank');
    });

    test('converts the old single-value cache format', () {
      final memory = MerchantMemory.fromMap({
        'name': 'ร้านเดิม',
        'mainCategoryId': 'living',
        'subCategoryId': 'drink',
        'walletId': 'cash',
        'count': 5,
        'lastUpdated': '2026-09-09T10:00:00.000',
      });

      expect(memory.samples, hasLength(1));
      expect(memory.mainCategoryId, 'living');
      expect(memory.subCategoryId, 'drink');
      expect(memory.walletId, 'cash');
    });
  });
}
