import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/report_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/savings_goal_provider.dart';
import '../../models/transaction_item.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/csv_exporter.dart';
import '../../core/utils/name_helper.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _splitFilterIndex = 0; // 0: ทั้งหมด, 1: กองกลาง, 2: ส่วนตัว
  bool _showAllCategories = false;
  int _touchedCategoryIndex = -1;

  // Custom Pastel Lifestyle Palette
  static const Color _softStrawberry = Color(0xFFFF6584);
  static const Color _warmPeach = Color(0xFFFF8E72);
  static const Color _mintPastel = Color(0xFF48BB78);
  static const Color _softCoral = Color(0xFFFF7A8A);
  static const Color _lavenderPastel = Color(0xFF9D84EA);
  static const Color _pastelCream = Color(0xFFFDFBF7);

  Widget _buildAvatar(String? photoBase64, String nickname, Color bgColor, {double size = 32}) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      if (photoBase64.startsWith('http')) {
        return CircleAvatar(
          radius: size / 2,
          backgroundImage: NetworkImage(photoBase64),
        );
      }
      try {
        final cleanBase64 = photoBase64.contains(',') ? photoBase64.split(',').last : photoBase64;
        return CircleAvatar(
          radius: size / 2,
          backgroundImage: MemoryImage(base64Decode(cleanBase64)),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bgColor.withOpacity(0.2),
      child: Text(
        nickname.isNotEmpty ? nickname.characters.first : '💕',
        style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.bold, color: bgColor),
      ),
    );
  }

  void _showSubCategoryBreakdown(String mainCatId, String mainCatName, String emoji, List<TransactionItem> allTxs) {
    final subCats = ref.read(subCategoriesProvider);
    final subCatMap = {for (var s in subCats) s.id: s};

    final catExpenses = allTxs.where((t) => t.type == 'expense' && t.mainCategoryId == mainCatId).toList();
    final Map<String, double> subMap = {};
    double total = 0;

    for (var tx in catExpenses) {
      final subName = subCatMap[tx.subCategoryId]?.name ?? tx.note ?? 'ทั่วไป';
      subMap[subName] = (subMap[subName] ?? 0) + tx.amount;
      total += tx.amount;
    }

    final sortedEntries = subMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mainCatName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ยอดรวม ${CurrencyFormatter.format(total)} (${catExpenses.length} รายการ)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (sortedEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('ไม่มีรายการย่อย')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sortedEntries.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, i) {
                      final entry = sortedEntries[i];
                      final pct = total > 0 ? (entry.value / total * 100) : 0.0;
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: _softStrawberry, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            CurrencyFormatter.format(entry.value),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _softCoral),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reportProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final filterNotifier = ref.read(transactionFiltersProvider.notifier);
    final mainCats = ref.watch(mainCategoriesProvider);
    final subCats = ref.watch(subCategoriesProvider);
    final wallets = ref.watch(walletsProvider);
    final transactions = ref.watch(filteredTransactionsProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider).value;
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);

    final theme = Theme.of(context);
    final monthName = DateFormatter.formatMonthYear(filters.selectedMonth);

    // Dynamic resolution of User & Partner Name & Photo according to user's exact specification:
    // 1. Check partner's nickname
    // 2. If partner hasn't set a nickname, pull name from their logged-in account (e.g. email prefix)
    // 3. If no partner connected yet, show "แฟน (รอเชื่อมต่อ)"
    final userName = NameHelper.resolveDisplayName(
      nickname: userProfile?.nickname,
      email: userProfile?.email,
      defaultFallback: 'ฉัน',
    );

    final String partnerName = NameHelper.resolveDisplayName(
      nickname: partnerProfile?.nickname,
      email: partnerProfile?.email,
      defaultFallback: 'แฟน',
    );

    final partnerPhoto = partnerProfile?.photoBase64;

    Future<void> exportCsv() async {
      try {
        final filename = 'รายงานการเงิน_${filters.selectedMonth.year}_${filters.selectedMonth.month}';
        await CsvExporter.shareCsv(
          transactions: transactions,
          mainCategories: mainCats,
          subCategories: subCats,
          wallets: wallets,
          filename: filename,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ส่งออกไม่สำเร็จ: $e')),
          );
        }
      }
    }

    // Couple Contribution Breakdown Calculation
    final expenses = transactions.where((t) => t.type == 'expense').toList();
    List<TransactionItem> filteredExpenses = expenses;
    if (_splitFilterIndex == 1) {
      // Shared expenses (living, food, home, pets, supermarket)
      filteredExpenses = expenses.where((t) {
        final cat = mainCats.firstWhere((c) => c.id == t.mainCategoryId, orElse: () => mainCats.first);
        final n = '${cat.name} ${t.note ?? ""} ${t.loveNote ?? ""}'.toLowerCase();
        return n.contains('living') || n.contains('พัก') || n.contains('อาหาร') || n.contains('บ้าน') || n.contains('กิน') || n.contains('ช้อป') || n.contains('ของใช้') || n.contains('แมว');
      }).toList();
    } else if (_splitFilterIndex == 2) {
      // Personal expenses
      filteredExpenses = expenses.where((t) {
        final cat = mainCats.firstWhere((c) => c.id == t.mainCategoryId, orElse: () => mainCats.first);
        final n = '${cat.name} ${t.note ?? ""} ${t.loveNote ?? ""}'.toLowerCase();
        return !n.contains('living') && !n.contains('พัก') && !n.contains('อาหาร') && !n.contains('ของใช้');
      }).toList();
    }

    double userTotalExpense = 0;
    double partnerTotalExpense = 0;

    for (var tx in filteredExpenses) {
      final isUser = userProfile != null && tx.createdByUserId == userProfile.id;
      if (isUser) {
        userTotalExpense += tx.amount;
      } else {
        partnerTotalExpense += tx.amount;
      }
    }
    final combinedExpense = userTotalExpense + partnerTotalExpense;
    final userPct = combinedExpense > 0 ? (userTotalExpense / combinedExpense * 100) : 0.0;
    final partnerPct = combinedExpense > 0 ? (partnerTotalExpense / combinedExpense * 100) : 0.0;

    // Date / Meal Count
    final dateMealCount = expenses.where((t) {
      final cat = mainCats.firstWhere((c) => c.id == t.mainCategoryId, orElse: () => mainCats.first);
      final n = '${cat.name} ${t.note ?? ""} ${t.loveNote ?? ""}'.toLowerCase();
      return n.contains('อาหาร') || n.contains('cafe') || n.contains('กิน') || n.contains('เดต') || n.contains('date');
    }).length;

    // Actual savings goals from stream (Never hardcoded!)
    final goals = goalsAsync.value ?? [];

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light ? _pastelCream : null,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: filters.selectedMonth,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              helpText: 'เลือกเดือนและปีที่ต้องการดูรายงาน',
            );
            if (picked != null) {
              filterNotifier.setMonth(picked);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => filterNotifier.previousMonth(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_left, size: 18),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.calendar_today, size: 14, color: _softStrawberry),
                const SizedBox(width: 6),
                Text(
                  monthName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => filterNotifier.nextMonth(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Dual Avatar Ring with Love Badge (User & Partner's actual photo/name)
          Container(
            margin: const EdgeInsets.only(right: 6),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _buildAvatar(userProfile?.photoBase64, userName, _softStrawberry, size: 28),
                    ),
                    Transform.translate(
                      offset: const Offset(-8, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: _buildAvatar(partnerPhoto, partnerName, _warmPeach, size: 28),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: -2,
                  left: 18,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Text('💕', style: TextStyle(fontSize: 9)),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: _softStrawberry, size: 20),
            tooltip: 'ส่งออก CSV รายงานการเงิน',
            onPressed: transactions.isEmpty ? null : exportCsv,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO SUMMARY CARD (Shared Cashflow Card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surface,
                    _softStrawberry.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _softStrawberry.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: _softStrawberry.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite, size: 16, color: _softStrawberry),
                          const SizedBox(width: 6),
                          Text(
                            'กระแสเงินสดคู่เรา ($monthName)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      // Supportive badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: report.netBalance >= 0 ? _mintPastel.withOpacity(0.12) : _softCoral.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          report.netBalance >= 0 ? 'เงินเหลือเก็บ 🎉' : 'เน้นสร้างสุข 💕',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: report.netBalance >= 0 ? _mintPastel : _softCoral,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Net cashflow number
                  Text(
                    CurrencyFormatter.format(report.netBalance, showSign: true),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: report.netBalance >= 0 ? _mintPastel : _softCoral,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.netBalance >= 0
                        ? 'เดือนนี้บริหารการเงินได้ดีมาก มีเงินเหลือต่อยอดเป้าหมายคู่รัก ✨'
                        : 'เดือนนี้เน้นสร้างความสุข ค่อยปรับแผนเดือนหน้ากันนะ 💕',
                    style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 18),

                  // Smooth Dual-Color Progress Bar
                  SizedBox(
                    height: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        children: [
                          if (report.totalIncome > 0)
                            Expanded(
                              flex: (report.totalIncome * 100).toInt().clamp(1, 10000),
                              child: Container(color: _mintPastel),
                            ),
                          if (report.totalExpense > 0)
                            Expanded(
                              flex: (report.totalExpense * 100).toInt().clamp(1, 10000),
                              child: Container(color: _softStrawberry),
                            ),
                          if (report.totalIncome == 0 && report.totalExpense == 0)
                            Expanded(child: Container(color: Colors.grey.shade200)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Income vs Expense 2 Columns
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _mintPastel.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: _mintPastel, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('รายรับรวม', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(
                                      CurrencyFormatter.format(report.totalIncome),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _mintPastel),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _softStrawberry.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: _softStrawberry, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('รายจ่ายรวม', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(
                                      CurrencyFormatter.format(report.totalExpense),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _softCoral),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. COUPLE CONTRIBUTION SPLIT ("Our Spending Ratio")
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        Icon(Icons.people, color: _softStrawberry, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'สัดส่วนการใช้จ่ายของคู่เรา',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Toggle Filter Chips: [ภาพรวมทั้งหมด | ค่าใช้จ่ายกองกลาง | ค่าใช้จ่ายส่วนตัว]
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('ภาพรวมทั้งหมด', style: TextStyle(fontSize: 11)),
                            selected: _splitFilterIndex == 0,
                            selectedColor: _softStrawberry.withOpacity(0.2),
                            onSelected: (val) => setState(() => _splitFilterIndex = 0),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('ค่าใช้จ่ายกองกลาง', style: TextStyle(fontSize: 11)),
                            selected: _splitFilterIndex == 1,
                            selectedColor: _softStrawberry.withOpacity(0.2),
                            onSelected: (val) => setState(() => _splitFilterIndex = 1),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('ค่าใช้จ่ายส่วนตัว', style: TextStyle(fontSize: 11)),
                            selected: _splitFilterIndex == 2,
                            selectedColor: _softStrawberry.withOpacity(0.2),
                            onSelected: (val) => setState(() => _splitFilterIndex = 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dual-segmented Comparison Bar
                    SizedBox(
                      height: 14,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Row(
                          children: [
                            if (userTotalExpense > 0)
                              Expanded(
                                flex: (userTotalExpense * 100).toInt().clamp(1, 10000),
                                child: Container(color: _lavenderPastel),
                              ),
                            if (partnerTotalExpense > 0)
                              Expanded(
                                flex: (partnerTotalExpense * 100).toInt().clamp(1, 10000),
                                child: Container(color: _warmPeach),
                              ),
                            if (combinedExpense == 0)
                              Expanded(child: Container(color: Colors.grey.shade200)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2 Avatar Sub-cards (User & Partner)
                    Row(
                      children: [
                        // Card A: User (ฉัน / dooodo)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _lavenderPastel.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _lavenderPastel.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildAvatar(userProfile?.photoBase64, userName, _lavenderPastel, size: 24),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        userName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  CurrencyFormatter.format(userTotalExpense),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _lavenderPastel),
                                ),
                                Text(
                                  '${userPct.toStringAsFixed(1)}% ของยอดรวม',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _lavenderPastel.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    userTotalExpense >= partnerTotalExpense ? 'สปอนเซอร์ใจดี 👑' : 'ช่วยประหยัด 💖',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _lavenderPastel),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Card B: Partner (ฝน หรือชื่อจากบัญชีล็อกอิน)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _warmPeach.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _warmPeach.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildAvatar(partnerPhoto, partnerName, _warmPeach, size: 24),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        partnerName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  CurrencyFormatter.format(partnerTotalExpense),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _warmPeach),
                                ),
                                Text(
                                  '${partnerPct.toStringAsFixed(1)}% ของยอดรวม',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _warmPeach.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    partnerTotalExpense >= userTotalExpense ? 'สปอนเซอร์ใจดี 👑' : 'รอคิวเลี้ยงเดือนหน้านะ 🥪',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _warmPeach),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. WHERE DID OUR MONEY GO? (Lifestyle Breakdown: Donut Chart + Right-Side Details)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pie_chart, color: _softStrawberry, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'สัดส่วนค่าใช้จ่ายตามหมวดหมู่',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '${report.categoryBreakdown.length} หมวด',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (report.categoryBreakdown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('ยังไม่มีประวัติการใช้จ่ายของเดือนนี้')),
                      )
                    else ...[
                      // Modern Split Row: Donut Chart (Left) + Category Pills (Right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left Donut Chart with Center Total Label
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 44,
                                    pieTouchData: PieTouchData(
                                      touchCallback: (event, pieTouchResponse) {
                                        setState(() {
                                          if (!event.isInterestedForInteractions ||
                                              pieTouchResponse == null ||
                                              pieTouchResponse.touchedSection == null) {
                                            _touchedCategoryIndex = -1;
                                            return;
                                          }
                                          _touchedCategoryIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                        });
                                      },
                                    ),
                                    sections: report.categoryBreakdown.asMap().entries.map((entry) {
                                      final i = entry.key;
                                      final data = entry.value;
                                      final isTouched = i == _touchedCategoryIndex;
                                      final color = AppColors.fromHex(data.colorHex);
                                      return PieChartSectionData(
                                        color: color,
                                        value: data.amount,
                                        title: isTouched ? '${data.percentage.toStringAsFixed(0)}%' : '',
                                        radius: isTouched ? 26 : 20,
                                        titleStyle: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'รวม',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(report.totalExpense),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Right Categories List
                          Expanded(
                            child: Column(
                              children: [
                                ...report.categoryBreakdown.take(_showAllCategories ? 100 : 3).map((item) {
                                  final color = AppColors.fromHex(item.colorHex);
                                  return InkWell(
                                    onTap: () => _showSubCategoryBreakdown(item.categoryId, item.categoryName, item.emoji, transactions),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.18),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(item.emoji, style: const TextStyle(fontSize: 14)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.categoryName,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  CurrencyFormatter.format(item.amount),
                                                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '${item.percentage.toStringAsFixed(0)}%',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Expand/Collapse Button
                      if (report.categoryBreakdown.length > 3)
                        Center(
                          child: TextButton.icon(
                            onPressed: () => setState(() => _showAllCategories = !_showAllCategories),
                            icon: Icon(_showAllCategories ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18),
                            label: Text(
                              _showAllCategories ? 'ย่อหมวดหมู่' : 'ดูหมวดหมู่ทั้งหมด (${report.categoryBreakdown.length})',
                              style: const TextStyle(fontSize: 12, color: _softStrawberry, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. COUPLE LIFESTYLE MILESTONE (บันทึกช่วงเวลาแห่งความสุขคู่เรา 🍿)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('🍿', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text(
                          'บันทึกช่วงเวลาแห่งความสุขคู่เรา',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bento Box 1: Date Meals Count (สถิติมื้อเดตจริง)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _warmPeach.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🍕 มื้อเดต & คาเฟ่คู่เรา', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Text(
                                  '$dateMealCount ครั้ง',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _warmPeach),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateMealCount > 0 ? 'เติมพลังใจให้กันทุกสัปดาห์ 💕' : 'ชวนกันไปเดตสักมื้อนะ 🥰',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Bento Box 2: Joint Saving Goal Progress (เป้าหมายออมเงินจริง - ไม่ Hardcode!)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _mintPastel.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('🎯 ออมคู่รัก', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (goals.isEmpty) ...[
                                  const Text(
                                    'ยังไม่มีเป้าหมาย',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'สร้างเป้าหมายออมเงินร่วมกันในหน้าภาพรวม ✨',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ] else ...[
                                  // Show active real goals (up to 2 in bento)
                                  ...goals.where((g) => !g.isCompleted).take(2).map((goal) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${goal.emoji} ${goal.title}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _mintPastel),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${goal.progressPercentage.toStringAsFixed(0)}%',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _mintPastel),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: (goal.progressPercentage / 100).clamp(0.0, 1.0),
                                            backgroundColor: Colors.white,
                                            color: _mintPastel,
                                            minHeight: 5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${CurrencyFormatter.format(goal.currentAmount)} / ${CurrencyFormatter.format(goal.targetAmount)}',
                                          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  )),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 5. GENTLE TAX DEDUCTIBLE SECTION (If Any)
            if (report.totalTaxDeductible > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lavenderPastel.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _lavenderPastel.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _lavenderPastel.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('📑', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'สิทธิประโยชน์ลดหย่อนภาษีคู่รักสะสม',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _lavenderPastel),
                          ),
                          Text(
                            CurrencyFormatter.format(report.totalTaxDeductible),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _lavenderPastel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
