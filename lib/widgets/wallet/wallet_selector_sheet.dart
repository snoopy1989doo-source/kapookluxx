import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet.dart';
import 'wallet_card.dart';

class WalletSelectorSheet extends ConsumerWidget {
  final Wallet? selectedWallet;
  final ValueChanged<Wallet> onWalletSelected;

  const WalletSelectorSheet({
    super.key,
    required this.selectedWallet,
    required this.onWalletSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'เลือกกระเป๋าเงิน',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (wallets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('ไม่มีกระเป๋าเงิน กรุณาเพิ่มก่อนใช้งาน'),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: wallets.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  final isSelected = selectedWallet?.id == wallet.id;
                  
                  return WalletCard(
                    wallet: wallet,
                    isSelected: isSelected,
                    onTap: () {
                      onWalletSelected(wallet);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static void show(
    BuildContext context, {
    required Wallet? selectedWallet,
    required ValueChanged<Wallet> onWalletSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) => WalletSelectorSheet(
        selectedWallet: selectedWallet,
        onWalletSelected: onWalletSelected,
      ),
    );
  }
}
