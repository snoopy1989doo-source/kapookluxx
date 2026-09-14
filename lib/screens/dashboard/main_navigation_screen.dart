import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import '../transaction/transaction_list_screen.dart';
import '../transaction/add_edit_transaction_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../models/transaction_item.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/name_helper.dart';
import '../../core/constants/app_colors.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  final Set<String> _knownTxIds = {};
  bool _isFirstLoad = true;

  void _navigateToTransactions() {
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider).value;
    final userProfile = ref.watch(userProfileProvider).value;
    final coupleRoom = ref.watch(coupleRoomProvider).value;

    // Auto-sync current user profile to couple_rooms document if changed or missing
    if (userProfile != null && coupleRoom != null) {
      final existingInfo = coupleRoom.membersInfo[userProfile.id];
      if (existingInfo == null ||
          existingInfo['nickname'] != userProfile.nickname ||
          existingInfo['email'] != userProfile.email ||
          existingInfo['photoBase64'] != userProfile.photoBase64) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(coupleNotifierProvider.notifier).syncMyProfile(userProfile, coupleRoom.id);
        });
      }
    }

    // Listen to real-time transactions stream for partner notifications
    ref.listen<List<TransactionItem>>(rawTransactionsProvider, (previous, next) {
      if (_isFirstLoad) {
        _knownTxIds.addAll(next.map((t) => t.id));
        if (next.isNotEmpty) {
          _isFirstLoad = false;
        }
        return;
      }

      final prevIds = previous?.map((t) => t.id).toSet() ?? <String>{};
      final newTxs = next.where((t) => !prevIds.contains(t.id) && !_knownTxIds.contains(t.id)).toList();

      for (var tx in newTxs) {
        _knownTxIds.add(tx.id);

        // Only notify if the transaction is recent (created within the last 5 minutes)
        final age = DateTime.now().difference(tx.createdAt).inMinutes.abs();
        if (age > 5) continue;

        // If transaction was created by partner
        if (tx.createdByUserId != null && tx.createdByUserId != currentUserId) {
          final partnerProfile = ref.read(partnerProfileProvider).value;
          final partnerName = NameHelper.resolveDisplayName(
            nickname: partnerProfile?.nickname ?? tx.createdByName,
            email: partnerProfile?.email,
            defaultFallback: 'แฟนของคุณ',
          );
          final typeText = tx.type == 'income' ? 'รายรับ' : 'รายจ่าย';
          final amountText = CurrencyFormatter.format(tx.amount);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Text('💕 ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      '[$partnerName] บันทึก$typeTextใหม่ $amountText ${tx.note != null ? "(${tx.note})" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFE91E63),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    });

    final List<Widget> screens = [
      DashboardScreen(onNavigateToTransactions: _navigateToTransactions),
      const TransactionListScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context: context,
                  index: 0,
                  unselectedIcon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'ภาพรวม',
                ),
                _buildNavItem(
                  context: context,
                  index: 1,
                  unselectedIcon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: 'รายการ',
                ),
                // Center Elevated Glowing Button
                _buildCenterAddButton(context),
                _buildNavItem(
                  context: context,
                  index: 2,
                  unselectedIcon: Icons.pie_chart_outline,
                  selectedIcon: Icons.pie_chart,
                  label: 'รายงาน',
                ),
                _buildNavItem(
                  context: context,
                  index: 3,
                  unselectedIcon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'ตั้งค่า',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData unselectedIcon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const activeColor = AppColors.brandStart;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(isDark ? 0.22 : 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              size: 22,
              color: isSelected ? activeColor : theme.colorScheme.onSurface.withOpacity(isDark ? 0.45 : 0.45),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : theme.colorScheme.onSurface.withOpacity(isDark ? 0.7 : 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddEditTransactionScreen()),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF6584),
              Color(0xFFFF8E72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6584).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
