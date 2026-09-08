import 'package:flutter/material.dart';

class WalletIcon extends StatelessWidget {
  final String value;
  final Color color;
  final double size;

  const WalletIcon({
    super.key,
    required this.value,
    required this.color,
    this.size = 22,
  });

  static const materialValues = {
    'account_balance_wallet',
    'account_balance',
    'payments',
    'credit_card',
  };

  static bool isEmoji(String value) =>
      value.isNotEmpty && !materialValues.contains(value);

  static IconData iconData(String value) {
    switch (value) {
      case 'account_balance':
        return Icons.account_balance;
      case 'payments':
        return Icons.payments;
      case 'credit_card':
        return Icons.credit_card;
      case 'account_balance_wallet':
      default:
        return Icons.account_balance_wallet;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEmoji(value)) {
      return Text(value, style: TextStyle(fontSize: size));
    }
    return Icon(iconData(value), color: color, size: size);
  }
}
