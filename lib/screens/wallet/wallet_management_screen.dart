import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/wallet.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/category/color_picker_dialog.dart';
import '../../widgets/category/emoji_picker_dialog.dart';
import '../../widgets/wallet/wallet_icon.dart';

class WalletManagementScreen extends ConsumerStatefulWidget {
  const WalletManagementScreen({super.key});

  @override
  ConsumerState<WalletManagementScreen> createState() => _WalletManagementScreenState();
}

class _WalletManagementScreenState extends ConsumerState<WalletManagementScreen> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  Color _dialogColor = AppColors.categoryPalette.first;
  String _selectedIcon = 'account_balance_wallet';

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _showAddEditWalletDialog([Wallet? existing]) {
    final transactions = ref.read(rawTransactionsProvider);
    double accumulatedTx = 0.0;
    if (existing != null) {
      final walletTxs = transactions.where((tx) => tx.walletId == existing.id);
      for (var tx in walletTxs) {
        if (tx.type == 'income') {
          accumulatedTx += tx.amount;
        } else if (tx.type == 'expense') {
          accumulatedTx -= tx.amount;
        }
      }
    }

    _nameController.text = existing?.name ?? '';
    final startBalController = TextEditingController(
      text: existing != null ? existing.startingBalance.toStringAsFixed(2) : '0.00',
    );
    final curBalController = TextEditingController(
      text: existing != null ? existing.currentBalance.toStringAsFixed(2) : '0.00',
    );
    _dialogColor = existing != null ? AppColors.fromHex(existing.color) : AppColors.categoryPalette.first;
    _selectedIcon = existing?.icon ?? 'account_balance_wallet';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final startVal = double.tryParse(startBalController.text.trim().replaceAll(',', '')) ?? 0.0;
          final previewCurrent = startVal + accumulatedTx;

          return AlertDialog(
            title: Text(existing == null ? 'เพิ่มกระเป๋าเงิน' : 'แก้ไขกระเป๋าเงิน'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อกระเป๋าเงิน',
                      hintText: 'เช่น เงินสด, กสิกรไทย, Make',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Starting Balance Input
                  TextField(
                    controller: startBalController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'ยอดเงินเริ่มต้น (บาท)',
                      hintText: '0.00',
                      helperText: 'เงินที่มีอยู่ก่อนเริ่มบันทึกในแอป',
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        final s = double.tryParse(val.trim().replaceAll(',', '')) ?? 0.0;
                        curBalController.text = (s + accumulatedTx).toStringAsFixed(2);
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // If editing existing, show live math breakdown
                  if (existing != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('• ธุรกรรมสะสมในแอป:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                accumulatedTx >= 0 ? "+${CurrencyFormatter.format(accumulatedTx)}" : CurrencyFormatter.format(accumulatedTx),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: accumulatedTx >= 0 ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('• ยอดคงเหลือปัจจุบัน:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              Text(
                                CurrencyFormatter.format(previewCurrent),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: previewCurrent >= 0 ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  DropdownButtonFormField<String>(
                    value: WalletIcon.materialValues.contains(_selectedIcon) ? _selectedIcon : null,
                    decoration: const InputDecoration(labelText: 'สัญลักษณ์'),
                    items: const [
                      DropdownMenuItem(value: 'account_balance_wallet', child: Row(children: [Icon(Icons.account_balance_wallet), SizedBox(width: 8), Text('กระเป๋าเงิน')])),
                      DropdownMenuItem(value: 'account_balance', child: Row(children: [Icon(Icons.account_balance), SizedBox(width: 8), Text('ธนาคาร')])),
                      DropdownMenuItem(value: 'payments', child: Row(children: [Icon(Icons.payments), SizedBox(width: 8), Text('เงินสด')])),
                      DropdownMenuItem(value: 'credit_card', child: Row(children: [Icon(Icons.credit_card), SizedBox(width: 8), Text('บัตรเครดิต')])),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => _selectedIcon = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => EmojiPickerDialog.show(context, (emoji) {
                      setDialogState(() => _selectedIcon = emoji);
                    }),
                    icon: WalletIcon(value: _selectedIcon, color: _dialogColor, size: 24),
                    label: Text(
                      WalletIcon.isEmoji(_selectedIcon)
                          ? 'อีโมจิที่เลือก: $_selectedIcon'
                          : 'เลือกอีโมจิแทนไอคอน',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('สีสัญลักษณ์: '),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => ColorPickerDialog.show(context, (color) {
                          setDialogState(() => _dialogColor = color);
                        }),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: _dialogColor, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty) {
                    final walletList = ref.read(walletsProvider);
                    final startingBalance = double.tryParse(startBalController.text.trim()) ?? 0.0;
                    final currentBalance = startingBalance + accumulatedTx;

                    final wallet = Wallet(
                      id: existing?.id ?? 'wallet_${const Uuid().v4()}',
                      name: _nameController.text.trim(),
                      color: AppColors.toHex(_dialogColor),
                      icon: _selectedIcon,
                      startingBalance: startingBalance,
                      currentBalance: currentBalance,
                      order: existing?.order ?? walletList.length,
                      createdAt: existing?.createdAt ?? DateTime.now(),
                    );
                    if (existing == null) {
                      ref.read(rawWalletsProvider.notifier).addWallet(wallet);
                    } else {
                      ref.read(rawWalletsProvider.notifier).updateWallet(wallet);
                    }
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteWallet(Wallet wallet) {
    ConfirmDialog.show(
      context,
      title: 'ลบกระเป๋าเงิน',
      content: 'คุณแน่ใจว่าต้องการลบกระเป๋าเงิน "${wallet.name}" หรือไม่?\n⚠️ การลบกระเป๋าเงินจะไม่ทำการลบประวัติธุรกรรมที่บันทึกไว้ แต่อาจส่งผลให้ยอดคงเหลือรวมคำนวณไม่ถูกต้อง',
      confirmText: 'ลบข้อมูล',
      confirmColor: AppColors.expense,
      onConfirm: () {
        ref.read(rawWalletsProvider.notifier).deleteWallet(wallet.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('กระเป๋าเงิน'),
      ),
      body: Column(
        children: [
          // Informative Formula & Helper Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 สูตรคำนวณ: ยอดปัจจุบัน = ยอดตั้งต้น + รายรับ - รายจ่าย',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'หากกระเป๋าเงินติดลบ แปลว่ามีบันทึกรายจ่ายมากกว่าเงินตั้งต้น สามารถกดแก้ไข ✏️ เพื่อใส่ยอดเงินเริ่มต้นตามเงินจริงได้เลยครับ',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: wallets.isEmpty
                ? const Center(child: Text('ไม่มีกระเป๋าเงิน กดปุ่ม + เพื่อเพิ่ม'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: wallets.length,
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final List<Wallet> reorderedList = List<Wallet>.from(wallets);
                      final item = reorderedList.removeAt(oldIndex);
                      reorderedList.insert(newIndex, item);
                      ref.read(rawWalletsProvider.notifier).reorderWallets(reorderedList);
                    },
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final wColor = AppColors.fromHex(wallet.color);

                      return Card(
                        key: ValueKey(wallet.id),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: wColor.withOpacity(0.12),
                            child: WalletIcon(value: wallet.icon, color: wColor),
                          ),
                          title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ยอดตั้งต้น: ${CurrencyFormatter.format(wallet.startingBalance)}'),
                              Text(
                                'ยอดปัจจุบัน: ${CurrencyFormatter.format(wallet.currentBalance)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: wallet.currentBalance >= 0 ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showAddEditWalletDialog(wallet),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: AppColors.expense, size: 20),
                                onPressed: () => _confirmDeleteWallet(wallet),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditWalletDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
