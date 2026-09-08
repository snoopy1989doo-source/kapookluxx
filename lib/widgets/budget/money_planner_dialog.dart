import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../../providers/category_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/bill_learning_service.dart';
import '../common/confirm_dialog.dart';

class MoneyPlannerDialog extends ConsumerStatefulWidget {
  const MoneyPlannerDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MoneyPlannerDialog(),
    );
  }

  @override
  ConsumerState<MoneyPlannerDialog> createState() => _MoneyPlannerDialogState();
}

class _MoneyPlannerDialogState extends ConsumerState<MoneyPlannerDialog> {
  /// Select category via clean modal bottom sheet (Fixing dropdown overflow)
  void _openCategoryPicker({
    required List<SubCategory> availableSubCats,
    required List<MainCategory> mainCats,
    required Function(SubCategory) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.category, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'เลือกหมวดหมู่ที่ต้องการเตรียมเงิน',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: availableSubCats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final sub = availableSubCats[index];
                        final main = mainCats.firstWhere(
                          (m) => m.id == sub.mainCategoryId,
                          orElse: () => MainCategory(
                            id: '',
                            name: 'ทั่วไป',
                            emoji: '📁',
                            color: '#1E88E5',
                            order: 0,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );

                        // Clean category name
                        final cleanName = sub.name.split('(').first.trim();
                        final cleanMainName = main.name.split('(').first.trim();

                        return InkWell(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onSelected(sub);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF242A38) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(sub.emoji, style: const TextStyle(fontSize: 20)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cleanName,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        cleanMainName,
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.55)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Add or Edit budget & due day dialog
  void _showAddOrEditBudgetDialog({SubCategory? existingSubCat, double? existingBudget, int? existingDueDay}) {
    final subCats = ref.read(subCategoriesProvider);
    final mainCats = ref.read(mainCategoriesProvider);
    final currentBudgets = ref.read(subcategoryBudgetsProvider);
    final dueDays = ref.read(recurringBillDueDaysProvider);
    final allTransactions = ref.read(rawTransactionsProvider);

    final availableSubCats = existingSubCat != null
        ? subCats
        : subCats.where((s) => !currentBudgets.containsKey(s.id)).toList();

    if (availableSubCats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณได้ตั้งงบเตรียมเงินให้กับทุกหมวดย่อยเรียบร้อยแล้ว')),
      );
      return;
    }

    SubCategory selectedSubCat = existingSubCat ?? availableSubCats.first;
    double historicalAverage = BillLearningService.calculateMonthlyAverage(allTransactions, selectedSubCat.id);
    int detectedDueDay = BillLearningService.detectTypicalDueDay(allTransactions, selectedSubCat.id);

    final amountController = TextEditingController(
      text: existingBudget != null
          ? existingBudget.toStringAsFixed(0)
          : (historicalAverage > 0 ? historicalAverage.toStringAsFixed(0) : ''),
    );

    int selectedDueDay = existingDueDay ?? (dueDays[selectedSubCat.id] ?? detectedDueDay);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  existingSubCat != null ? '✏️ แก้ไขแผนเตรียมเงิน' : '🎯 เพิ่มบิล / เตรียมเงิน',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'กำหนดงบประมาณรายจ่ายและวันที่ครบกำหนดจ่ายประจำเดือน',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),

                  // Category Selector Button (Clean Bottom Sheet instead of messy dropdown)
                  if (existingSubCat == null) ...[
                    InkWell(
                      onTap: () {
                        _openCategoryPicker(
                          availableSubCats: availableSubCats,
                          mainCats: mainCats,
                          onSelected: (picked) {
                            setDialogState(() {
                              selectedSubCat = picked;
                              historicalAverage = BillLearningService.calculateMonthlyAverage(allTransactions, picked.id);
                              detectedDueDay = BillLearningService.detectTypicalDueDay(allTransactions, picked.id);
                              selectedDueDay = detectedDueDay;
                              if (historicalAverage > 0 && amountController.text.isEmpty) {
                                amountController.text = historicalAverage.toStringAsFixed(0);
                              }
                            });
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(selectedSubCat.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedSubCat.name.split('(').first.trim(),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Text('เปลี่ยนหมวด', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Historical Average Helper Card
                  if (historicalAverage > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_graph, size: 16, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ยอดจ่ายเฉลี่ย: ฿${CurrencyFormatter.format(historicalAverage)} / เดือน',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.brown.shade800),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                amountController.text = historicalAverage.toStringAsFixed(0);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('ใช้ยอดนี้', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Amount Field
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'จำนวนเงินเตรียมไว้ (บาท/เดือน)',
                      hintText: 'เช่น 3,000',
                      prefixText: '฿ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Due Day of Month (1-31)
                  Row(
                    children: [
                      const Icon(Icons.event, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'วันที่ต้องจ่ายประจำของเดือน:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      DropdownButton<int>(
                        value: selectedDueDay,
                        items: List.generate(31, (i) => i + 1).map((day) {
                          return DropdownMenuItem<int>(
                            value: day,
                            child: Text('วันที่ $day', style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedDueDay = val);
                          }
                        },
                      ),
                    ],
                  ),
                  Text(
                    '💡 แนะนำวันที่ $detectedDueDay (ระบบตรวจพบว่ามักจ่ายช่วงวันนี้)',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim().replaceAll(',', ''));
                  if (amount != null && amount > 0) {
                    final roomId = ref.read(coupleRoomIdProvider);
                    if (roomId != null) {
                      await ref.read(coupleRepositoryProvider).setSubcategoryBudget(
                            roomId,
                            selectedSubCat.id,
                            amount,
                            dueDay: selectedDueDay,
                          );
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✨ บันทึกการเตรียมเงิน ${CurrencyFormatter.format(amount)} เรียบร้อย')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Delete budget item confirmation
  void _confirmDeleteBudget(String subCatId, String subCatName) {
    ConfirmDialog.show(
      context,
      title: 'ลบรายการเตรียมเงิน',
      content: 'คุณแน่ใจหรือไม่ว่าต้องการลบรายการ "$subCatName" ออกจากแผนเตรียมเงินประจำเดือน?',
      confirmText: 'ลบรายการ',
      confirmColor: AppColors.expense,
      onConfirm: () async {
        final roomId = ref.read(coupleRoomIdProvider);
        if (roomId != null) {
          await ref.read(coupleRepositoryProvider).removeSubcategoryBudget(roomId, subCatId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ลบรายการ "$subCatName" เรียบร้อย')),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final budgets = ref.watch(subcategoryBudgetsProvider);
    final dueDays = ref.watch(recurringBillDueDaysProvider);
    final subCats = ref.watch(subCategoriesProvider);
    final transactions = ref.watch(filteredTransactionsProvider);
    final allTransactions = ref.watch(rawTransactionsProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final monthName = DateFormatter.formatMonthYear(filters.selectedMonth);

    // Calculate actual spending per subcategory
    final Map<String, double> subCatSpending = {};
    for (var tx in transactions) {
      if (tx.type == 'expense' && tx.subCategoryId.isNotEmpty) {
        subCatSpending[tx.subCategoryId] = (subCatSpending[tx.subCategoryId] ?? 0.0) + tx.amount;
      }
    }

    // Totals
    double totalBudget = 0;
    double totalSpentInBudgetedCats = 0;
    for (var entry in budgets.entries) {
      totalBudget += entry.value;
      totalSpentInBudgetedCats += (subCatSpending[entry.key] ?? 0.0);
    }
    final remainingBudget = totalBudget - totalSpentInBudgetedCats;

    // Discover unplanned recurring bills
    final discoveredBills = BillLearningService.discoverUnplannedRecurringBills(
      allTransactions,
      budgets,
      subCats,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Pull Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.teal.withOpacity(0.2) : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.account_balance_wallet, color: Colors.teal.shade700, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'แผนเตรียมเงิน & บิลประจำ 📋',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'จัดสรรเงินเดือน & เตือนวันจ่าย ($monthName)',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.55)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddOrEditBudgetDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('เพิ่มบิล', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Card (Planned vs Spent vs Remaining)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E2638), const Color(0xFF161E2E)]
                          : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatColumn('เตรียมไว้ทั้งหมด', CurrencyFormatter.format(totalBudget), Colors.indigo.shade700, isDark),
                          Container(width: 1, height: 36, color: Colors.grey.withOpacity(0.2)),
                          _buildStatColumn('ใช้จริงแล้ว', CurrencyFormatter.format(totalSpentInBudgetedCats), AppColors.expense, isDark),
                          Container(width: 1, height: 36, color: Colors.grey.withOpacity(0.2)),
                          _buildStatColumn(
                            'เงินคงเหลือ',
                            CurrencyFormatter.format(remainingBudget),
                            remainingBudget >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            isDark,
                          ),
                        ],
                      ),
                      if (totalBudget > 0) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (totalSpentInBudgetedCats / totalBudget).clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: Colors.white.withOpacity(0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              totalSpentInBudgetedCats > totalBudget ? Colors.red : Colors.indigo.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Smart Discovered Recurring Bills Banner
              if (discoveredBills.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF292418) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Text(discoveredBills.first.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '✨ ตรวจพบบิลประจำจากประวัติ:',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                              ),
                              Text(
                                '${discoveredBills.first.title} (เฉลี่ย ฿${CurrencyFormatter.format(discoveredBills.first.monthlyAverage)} จ่ายทุกวันที่ ${discoveredBills.first.detectedDueDay})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () {
                            final b = discoveredBills.first;
                            final sub = subCats.firstWhere((s) => s.id == b.subCategoryId);
                            _showAddOrEditBudgetDialog(
                              existingSubCat: sub,
                              existingBudget: b.monthlyAverage,
                              existingDueDay: b.detectedDueDay,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('+ เพิ่มเข้าแผน', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // List of Budgeted Items
              Expanded(
                child: budgets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('ยังไม่ได้ตั้งงบเตรียมเงินประจำเดือน', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showAddOrEditBudgetDialog(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('เริ่มวางแผนเตรียมเงินกองแรก (เช่น ค่ากิน, ค่าน้ำมัน, ค่าห้อง)'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: budgets.entries.length,
                        itemBuilder: (context, index) {
                          final entry = budgets.entries.elementAt(index);
                          final subCatId = entry.key;
                          final planned = entry.value;
                          final spent = subCatSpending[subCatId] ?? 0.0;
                          final ratio = planned > 0 ? (spent / planned) : 0.0;
                          final dueDay = dueDays[subCatId];

                          final subCat = subCats.firstWhere(
                            (s) => s.id == subCatId,
                            orElse: () => SubCategory(id: subCatId, mainCategoryId: '', name: 'หมวดย่อย', emoji: '🏷️', color: '#E91E63', order: 0),
                          );

                          final cleanName = subCat.name.split('(').first.trim();
                          final billStatus = BillLearningService.getBillStatus(
                            allTransactions,
                            subCatId,
                            configuredDueDay: dueDay,
                            currentMonth: filters.selectedMonth,
                          );

                          final isOver = spent > planned;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isOver ? Colors.red.shade300 : theme.colorScheme.outlineVariant.withOpacity(0.6),
                                width: isOver ? 1.2 : 0.8,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(subCat.emoji, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cleanName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: billStatus.statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              billStatus.statusText,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: billStatus.statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          isOver
                                              ? '⚠️ เกิน +${CurrencyFormatter.format(spent - planned)}'
                                              : 'เหลือ ฿${CurrencyFormatter.format(planned - spent)}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: isOver ? Colors.red.shade700 : Colors.green.shade700,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            // Edit Button
                                            IconButton(
                                              icon: const Icon(Icons.edit, size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              color: Colors.grey,
                                              tooltip: 'แก้ไข',
                                              onPressed: () => _showAddOrEditBudgetDialog(
                                                existingSubCat: subCat,
                                                existingBudget: planned,
                                                existingDueDay: dueDay,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Delete Button (🗑️)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              color: AppColors.expense,
                                              tooltip: 'ลบรายการ',
                                              onPressed: () => _confirmDeleteBudget(subCatId, cleanName),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: ratio.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: Colors.grey.withOpacity(0.12),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isOver ? Colors.red : (ratio >= 0.8 ? Colors.amber.shade700 : Colors.green.shade600),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ใช้ไป: ${CurrencyFormatter.format(spent)}',
                                      style: TextStyle(fontSize: 10.5, color: isOver ? Colors.red : theme.colorScheme.onSurface.withOpacity(0.6)),
                                    ),
                                    Text(
                                      'เตรียมไว้: ${CurrencyFormatter.format(planned)}',
                                      style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
