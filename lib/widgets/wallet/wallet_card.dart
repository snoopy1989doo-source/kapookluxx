import 'package:flutter/material.dart';
import '../../models/wallet.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import 'wallet_icon.dart';

class WalletCard extends StatelessWidget {
  final Wallet wallet;
  final VoidCallback? onTap;
  final bool isSelected;

  const WalletCard({
    super.key,
    required this.wallet,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final walletColor = AppColors.fromHex(wallet.color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 164,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? Colors.white
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? walletColor
                : (theme.brightness == Brightness.light
                    ? AppColors.dividerLight
                    : AppColors.dividerDark),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: walletColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: WalletIcon(
                      value: wallet.icon, color: walletColor, size: 20),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: walletColor,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyFormatter.format(wallet.currentBalance),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: wallet.currentBalance >= 0
                            ? theme.colorScheme.onSurface
                            : AppColors.expense,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
