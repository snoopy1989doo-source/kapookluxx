import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/savings_goal_provider.dart';
import '../../widgets/wallet/wallet_card.dart';
import '../../widgets/transaction/transaction_tile.dart';
import '../../widgets/common/empty_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/name_helper.dart';
import '../../models/sub_category.dart';
import '../../services/bill_learning_service.dart';
import '../../widgets/budget/money_planner_dialog.dart';
import '../../widgets/couple/couple_quests_widget.dart';
import '../../widgets/couple/food_decision_wheel_dialog.dart';
import '../../widgets/couple/couple_savings_widget.dart';
import '../../widgets/couple/couple_calendar_dialog.dart';
import '../../widgets/budget/subcategory_budget_widget.dart';
import '../../models/transaction_item.dart';
import '../transaction/add_edit_transaction_screen.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback onNavigateToTransactions;

  const DashboardScreen({super.key, required this.onNavigateToTransactions});

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
        nickname.isNotEmpty ? nickname.characters.first : '👤',
        style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.bold, color: bgColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    final recentTransactions = ref.watch(rawTransactionsProvider).take(4).toList();
    final report = ref.watch(reportProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final filterNotifier = ref.read(transactionFiltersProvider.notifier);

    final mainCats = ref.watch(mainCategoriesProvider);
    final subCats = ref.watch(subCategoriesProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider).value;
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);
    final roomAsync = ref.watch(coupleRoomProvider);

    final mainCatMap = {for (var c in mainCats) c.id: c};
    final subCatMap = {for (var s in subCats) s.id: s};
    final walletMap = {for (var w in wallets) w.id: w};

    final theme = Theme.of(context);

    // Sum total balance across all wallets
    final totalAssets = wallets.fold<double>(0, (sum, w) => sum + w.currentBalance);

    // User & Partner names
    final userName = NameHelper.resolveDisplayName(
      nickname: userProfile?.nickname,
      email: userProfile?.email,
      defaultFallback: 'ฉัน',
    );

    final partnerName = NameHelper.resolveDisplayName(
      nickname: partnerProfile?.nickname,
      email: partnerProfile?.email,
      defaultFallback: 'แฟน',
    );

    final goals = goalsAsync.value ?? [];
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    final room = roomAsync.value;
    final subBudgets = room?.subcategoryBudgets ?? {};

    // Auto-sync current user's profile to couple_rooms document if changed or missing
    if (userProfile != null && room != null) {
      final existingInfo = room.membersInfo[userProfile.id];
      if (existingInfo == null ||
          existingInfo['nickname'] != userProfile.nickname ||
          existingInfo['email'] != userProfile.email ||
          existingInfo['photoBase64'] != userProfile.photoBase64) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(coupleNotifierProvider.notifier).syncMyProfile(userProfile, room.id);
        });
      }
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(rawWalletsProvider.notifier).loadWallets();
            ref.read(rawTransactionsProvider.notifier).loadTransactions();
            ref.read(mainCategoriesProvider.notifier).loadCategories();
            ref.read(subCategoriesProvider.notifier).loadSubCategories();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Compact Header: Avatar + Greetings + Month Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildAvatar(userProfile?.photoBase64, userName, AppColors.primary, size: 36),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              partnerProfile != null ? 'กระเป๋าคู่รัก 💕' : 'สวัสดีครับ 👋',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withOpacity(0.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              partnerProfile != null ? '$userName & $partnerName' : userName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Month Controller Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => filterNotifier.previousMonth(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.chevron_left, size: 16),
                            ),
                          ),
                          Text(
                            DateFormatter.formatSmartMonth(filters.selectedMonth),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          InkWell(
                            onTap: () => filterNotifier.nextMonth(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.chevron_right, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Compact All-in-One Financial Hero Card (Net Wealth + Monthly Income & Expense)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF6584),
                        Color(0xFFFF8E72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6584).withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'ยอดคงเหลือรวมทุกกระเป๋า 💰',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${wallets.length} กระเป๋า',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.format(totalAssets),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Integrated Dual-Pill for Income & Expense
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            // Income
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.arrow_upward, size: 12, color: Color(0xFF2E7D32)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('รายรับเดือนนี้', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            CurrencyFormatter.format(report.totalIncome),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 28, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(width: 10),
                            // Expense
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.arrow_downward, size: 12, color: Color(0xFFC62828)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('รายจ่ายเดือนนี้', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            CurrencyFormatter.format(report.totalExpense),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                            maxLines: 1,
                                          ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Quick Action Grid (4 Clean Minimalist Buttons in One Row)
                Row(
                  children: [
                    // 1. Scan Slip
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddEditTransactionScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6584).withOpacity(theme.brightness == Brightness.dark ? 0.16 : 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFF6584).withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.2)),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFFFF6584)),
                              SizedBox(height: 4),
                              Text('สแกนสลิป', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF6584))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Money Planner (เตรียมเงิน)
                    Expanded(
                      child: InkWell(
                        onTap: () => MoneyPlannerDialog.show(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark ? Colors.indigo.withOpacity(0.18) : Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.brightness == Brightness.dark ? Colors.indigo.withOpacity(0.35) : Colors.indigo.shade200),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.account_balance_wallet, size: 18, color: theme.brightness == Brightness.dark ? const Color(0xFFA5B4FC) : Colors.indigo.shade700),
                              const SizedBox(height: 4),
                              Text('เตรียมเงิน 📋', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.brightness == Brightness.dark ? const Color(0xFFA5B4FC) : Colors.indigo.shade700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. Food Wheel
                    Expanded(
                      child: InkWell(
                        onTap: () => FoodDecisionWheelDialog.show(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark ? Colors.orange.withOpacity(0.18) : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.brightness == Brightness.dark ? Colors.orange.withOpacity(0.35) : Colors.orange.shade200),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.casino, size: 18, color: theme.brightness == Brightness.dark ? const Color(0xFFFDBA74) : Colors.orange.shade800),
                              const SizedBox(height: 4),
                              Text('กินอะไรดี? 🎰', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.brightness == Brightness.dark ? const Color(0xFFFDBA74) : Colors.orange.shade800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 4. Love Calendar
                    Expanded(
                      child: InkWell(
                        onTap: () => CoupleCalendarDialog.show(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark ? Colors.pink.withOpacity(0.18) : Colors.pink.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.brightness == Brightness.dark ? Colors.pink.withOpacity(0.35) : Colors.pink.shade200),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month, size: 18, color: theme.brightness == Brightness.dark ? const Color(0xFFF472B6) : Colors.pink.shade700),
                              const SizedBox(height: 4),
                              Text('ปฏิทินรัก 📅', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.brightness == Brightness.dark ? const Color(0xFFF472B6) : Colors.pink.shade700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Compact Bill Reminder Ribbon
                _buildCompactBillReminderRibbon(context, ref, ref.watch(rawTransactionsProvider)),
                const SizedBox(height: 14),

                // 5. Couple Life Bento Grid (Savings Pot & Budget Side-by-Side)
                Row(
                  children: [
                    // Bento 1: Couple Savings Goals
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Text('🐷', style: TextStyle(fontSize: 15)),
                                    SizedBox(width: 4),
                                    Text('ออมคู่รัก', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                if (activeGoals.isNotEmpty)
                                  Text(
                                    '${activeGoals.first.progressPercentage.toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF48BB78)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (activeGoals.isEmpty) ...[
                              Text('ยังไม่มีเป้าหมาย', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () {
                                  // Open savings widget dialog or trigger
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                    builder: (ctx) => const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CoupleSavingsWidget(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6584).withOpacity(theme.brightness == Brightness.dark ? 0.22 : 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('+ สร้างเป้าหมาย ✨', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF6584))),
                                ),
                              ),
                            ] else ...[
                              Text(
                                '${activeGoals.first.emoji} ${activeGoals.first.title}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (activeGoals.first.progressPercentage / 100).clamp(0.0, 1.0),
                                  backgroundColor: theme.brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200,
                                  color: const Color(0xFF48BB78),
                                  minHeight: 5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Bento 2: Subcategory Budget
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('🎯', style: TextStyle(fontSize: 15)),
                                    SizedBox(width: 4),
                                    Text('คุมงบหมวด', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (subBudgets.isEmpty) ...[
                              Text('ยังไม่ตั้งงบหมวดย่อย', style: TextStyle(fontSize: 11, color: theme.brightness == Brightness.dark ? Colors.white60 : Colors.grey.shade600)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                    builder: (ctx) => const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: SubcategoryBudgetWidget(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(theme.brightness == Brightness.dark ? 0.22 : 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('+ ตั้งงบพิเศษ 🎯', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ),
                              ),
                            ] else ...[
                              Text(
                                'คุมงบ ${subBudgets.length} หมวด',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ดูรายละเอียดงบประมาณ',
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 6. Couple Quest & Daily Love Horoscope Compact Bar
                const CoupleQuestsWidget(),
                const SizedBox(height: 16),

                // 7. Horizontal Wallets List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'กระเป๋าเงิน',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onNavigateToTransactions,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (wallets.isEmpty)
                  const Center(child: Text('ยังไม่มีกระเป๋าเงิน'))
                else
                  SizedBox(
                    height: 126,
                    child: RepaintBoundary(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: wallets.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final wallet = wallets[index];
                          return WalletCard(
                            wallet: wallet,
                            onTap: () {
                              filterNotifier.setWallet(wallet.id);
                              onNavigateToTransactions();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 18),

                // 8. Recent Transactions List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ธุรกรรมล่าสุด',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: onNavigateToTransactions,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                      child: const Text('ดูทั้งหมด', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (recentTransactions.isEmpty)
                  EmptyState(
                    title: 'ยังไม่มีประวัติการบันทึก',
                    description: 'กดปุ่ม + ด้านล่างเพื่อเริ่มสร้างรายการแรกของคุณ',
                    onButtonPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddEditTransactionScreen()),
                      );
                    },
                    buttonText: 'บันทึกรายการแรก',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentTransactions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final tx = recentTransactions[index];
                      final mainCat = mainCatMap[tx.mainCategoryId];
                      final subCat = subCatMap[tx.subCategoryId];
                      final wallet = walletMap[tx.walletId];

                      return TransactionTile(
                        transaction: tx,
                        mainCategory: mainCat,
                        subCategory: subCat,
                        wallet: wallet,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AddEditTransactionScreen(transaction: tx)),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBillReminderRibbon(BuildContext context, WidgetRef ref, List<TransactionItem> transactions) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final budgets = ref.watch(subcategoryBudgetsProvider);
    final dueDays = ref.watch(recurringBillDueDaysProvider);
    final subCats = ref.watch(subCategoriesProvider);

    String emoji = '🔔';
    String title = 'บิลประจำเดือน';
    String description = 'วางแผนเตรียมเงินและติดตามวันครบกำหนดจ่าย';

    if (budgets.isNotEmpty) {
      BillStatusInfo? mostUrgentStatus;
      String? mostUrgentName;
      String? mostUrgentEmoji;
      double? mostUrgentBudget;

      for (final entry in budgets.entries) {
        final subCatId = entry.key;
        final dueDay = dueDays[subCatId];
        final status = BillLearningService.getBillStatus(
          transactions,
          subCatId,
          configuredDueDay: dueDay,
        );

        final subCat = subCats.firstWhere(
          (s) => s.id == subCatId,
          orElse: () => SubCategory(id: subCatId, mainCategoryId: '', name: 'บิล', emoji: '🧾', color: '#607D8B', order: 0),
        );

        // Priority 1: Due today or overdue
        if (status.isDueToday || status.isOverdue) {
          mostUrgentStatus = status;
          mostUrgentName = subCat.name.split('(').first.trim();
          mostUrgentEmoji = subCat.emoji;
          mostUrgentBudget = entry.value;
          break;
        }

        // Priority 2: Unpaid and nearest due date
        if (!status.hasPaidThisMonth) {
          if (mostUrgentStatus == null || status.daysRemaining < mostUrgentStatus.daysRemaining) {
            mostUrgentStatus = status;
            mostUrgentName = subCat.name.split('(').first.trim();
            mostUrgentEmoji = subCat.emoji;
            mostUrgentBudget = entry.value;
          }
        }
      }

      if (mostUrgentStatus != null && mostUrgentName != null) {
        emoji = mostUrgentEmoji ?? '⚡';
        title = mostUrgentName;
        description = '${mostUrgentStatus.statusText} • เตรียมไว้ ฿${CurrencyFormatter.format(mostUrgentBudget ?? 0)}';
      } else {
        emoji = '🎉';
        title = 'จ่ายบิลครบถ้วนแล้ว';
        description = 'บิลประจำเดือนนี้ทุกรายการจัดการเรียบร้อยแล้ว ยอดเยี่ยมมาก!';
      }
    } else {
      final discovered = BillLearningService.discoverUnplannedRecurringBills(transactions, budgets, subCats);
      if (discovered.isNotEmpty) {
        final first = discovered.first;
        emoji = first.emoji;
        title = first.title.split('(').first.trim();
        description = 'จ่ายประจำเฉลี่ย ฿${CurrencyFormatter.format(first.monthlyAverage)} ทุกวันที่ ${first.detectedDueDay}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2235) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.blueGrey.withOpacity(0.35) : Colors.blueGrey.shade200),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'บิลประจำเดือน',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withOpacity(0.65)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => MoneyPlannerDialog.show(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_calendar, size: 11, color: Colors.white),
                  SizedBox(width: 3),
                  Text('คุมงบ', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
