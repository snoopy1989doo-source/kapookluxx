import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/onboarding_provider.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../../models/wallet.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/category/color_picker_dialog.dart';
import '../../widgets/category/emoji_picker_dialog.dart';

class GuidedOnboardingScreen extends ConsumerStatefulWidget {
  const GuidedOnboardingScreen({super.key});

  @override
  ConsumerState<GuidedOnboardingScreen> createState() => _GuidedOnboardingScreenState();
}

class _GuidedOnboardingScreenState extends ConsumerState<GuidedOnboardingScreen> {
  // Local controllers for adding custom elements
  final _customNameController = TextEditingController();
  Color _selectedColor = AppColors.categoryPalette.first;
  String _selectedEmoji = '📁';
  String? _selectedMainCategoryIdForSub;

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  void _showAddCustomMainCategory() {
    _customNameController.clear();
    _selectedColor = AppColors.categoryPalette.first;
    _selectedEmoji = '📁';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('เพิ่มหมวดหมู่หลัก'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _customNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อหมวดหมู่หลัก',
                  hintText: 'เช่น ค่าอาหารพิเศษ, เลี้ยงสัตว์',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('สี', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => ColorPickerDialog.show(context, (color) {
                          setDialogState(() => _selectedColor = color);
                        }),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Emoji', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => EmojiPickerDialog.show(context, (emoji) {
                          setDialogState(() => _selectedEmoji = emoji);
                        }),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            shape: BoxShape.circle,
                          ),
                          child: Text(_selectedEmoji, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_customNameController.text.trim().isNotEmpty) {
                  final newCat = MainCategory(
                    id: 'custom_cat_${const Uuid().v4()}',
                    name: _customNameController.text.trim(),
                    color: AppColors.toHex(_selectedColor),
                    emoji: _selectedEmoji,
                    order: 99,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  ref.read(onboardingFlowProvider.notifier).addCustomMainCategory(newCat);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomSubCategory(List<MainCategory> selectedMainCats) {
    if (selectedMainCats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกหรือสร้างหมวดหมู่หลักอย่างน้อย 1 หมวดก่อนเพิ่มหมวดย่อย')),
      );
      return;
    }
    _customNameController.clear();
    _selectedEmoji = '📄';
    _selectedMainCategoryIdForSub = selectedMainCats.first.id;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final parentCat = selectedMainCats.firstWhere((c) => c.id == _selectedMainCategoryIdForSub);
          return AlertDialog(
            title: const Text('เพิ่มหมวดย่อย'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedMainCategoryIdForSub,
                  decoration: const InputDecoration(labelText: 'หมวดหมู่หลัก'),
                  items: selectedMainCats.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Row(
                        children: [
                          Text(cat.emoji),
                          const SizedBox(width: 8),
                          Text(cat.name, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => _selectedMainCategoryIdForSub = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customNameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อหมวดย่อย',
                    hintText: 'เช่น ข้าวเที่ยง, อุปกรณ์ไอที',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Emoji: '),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => EmojiPickerDialog.show(context, (emoji) {
                        setDialogState(() => _selectedEmoji = emoji);
                      }),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          shape: BoxShape.circle,
                        ),
                        child: Text(_selectedEmoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_customNameController.text.trim().isNotEmpty && _selectedMainCategoryIdForSub != null) {
                    final newSub = SubCategory(
                      id: 'custom_sub_${const Uuid().v4()}',
                      mainCategoryId: _selectedMainCategoryIdForSub!,
                      name: _customNameController.text.trim(),
                      emoji: _selectedEmoji,
                      color: parentCat.color,
                      order: 99,
                    );
                    ref.read(onboardingFlowProvider.notifier).addCustomSubCategory(newSub);
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

  void _showAddCustomWallet() {
    _customNameController.clear();
    _selectedColor = AppColors.categoryPalette.first;
    String selectedIcon = 'account_balance_wallet';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('เพิ่มกระเป๋าเงิน'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _customNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อกระเป๋าเงิน',
                  hintText: 'เช่น เงินสด, กรุงไทย',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedIcon,
                decoration: const InputDecoration(labelText: 'สัญลักษณ์'),
                items: const [
                  DropdownMenuItem(value: 'account_balance_wallet', child: Row(children: [Icon(Icons.account_balance_wallet), SizedBox(width: 8), Text('กระเป๋าเงิน')])),
                  DropdownMenuItem(value: 'account_balance', child: Row(children: [Icon(Icons.account_balance), SizedBox(width: 8), Text('ธนาคาร')])),
                  DropdownMenuItem(value: 'payments', child: Row(children: [Icon(Icons.payments), SizedBox(width: 8), Text('เงินสด/เหรียญ')])),
                  DropdownMenuItem(value: 'credit_card', child: Row(children: [Icon(Icons.credit_card), SizedBox(width: 8), Text('บัตรเครดิต')])),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedIcon = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('สีของกระเป๋าเงิน: '),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => ColorPickerDialog.show(context, (color) {
                      setDialogState(() => _selectedColor = color);
                    }),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_customNameController.text.trim().isNotEmpty) {
                  final onboardingState = ref.read(onboardingFlowProvider);
                  final newWallet = Wallet(
                    id: 'custom_wallet_${const Uuid().v4()}',
                    name: _customNameController.text.trim(),
                    color: AppColors.toHex(_selectedColor),
                    icon: selectedIcon,
                    startingBalance: 0.0,
                    currentBalance: 0.0,
                    order: onboardingState.selectedWallets.length,
                    createdAt: DateTime.now(),
                  );
                  ref.read(onboardingFlowProvider.notifier).addCustomWallet(newWallet);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingFlowProvider);
    final notifier = ref.read(onboardingFlowProvider.notifier);
    final theme = Theme.of(context);

    // --- Step 1: Welcome Screen ---
    Widget buildStep1() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waving_hand, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'ยินดีต้อนรับสู่แอปบันทึกเงินของคุณ!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'มาเริ่มสร้างกระเป๋าเงินและหมวดหมู่การใช้จ่ายในแบบของคุณ เพื่อตั้งต้นความมีสุขภาพการเงินที่ดีกันครับ',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), height: 1.5),
            ),
            const SizedBox(height: 48),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text('เริ่มต้นด้วยเทมเพลตมาตรฐาน (Living, Food, Transport)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('มีรายการและโครงสร้างมาตรฐานจัดไว้ให้เรียบร้อย สามารถปรับแก้ได้ตลอดเวลา'),
                    value: true,
                    groupValue: onboardingState.useTemplate,
                    onChanged: (val) => notifier.setUseTemplate(true),
                  ),
                  const Divider(),
                  RadioListTile<bool>(
                    title: const Text('สร้างเองใหม่ทั้งหมดตั้งแต่ศูนย์', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('เหมาะสำหรับคนที่ต้องการตั้งชื่อ สี และประเภทต่างๆ ด้วยตัวเองทั้งหมด'),
                    value: false,
                    groupValue: onboardingState.useTemplate,
                    onChanged: (val) => notifier.setUseTemplate(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // --- Step 2: Main Categories Setup ---
    Widget buildStep2() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'กำหนดหมวดหมู่หลัก (Main Categories)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'เลือกหมวดหมู่ที่เหมาะสมสำหรับการแยกกลุ่มค่าใช้จ่ายหลักของคุณ',
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: onboardingState.selectedMainCategories.length,
                itemBuilder: (context, index) {
                  final cat = onboardingState.selectedMainCategories[index];
                  final catColor = AppColors.fromHex(cat.color);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: catColor.withOpacity(0.12),
                        child: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                      ),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
                        onPressed: () => notifier.toggleMainCategorySelection(cat),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showAddCustomMainCategory,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มหมวดหมู่หลักกำหนดเอง'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      );
    }

    // --- Step 3: Sub Categories Setup ---
    Widget buildStep3() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ตั้งค่าหมวดหม่วย่อย (Sub Categories)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'เพิ่มความละเอียดในการจัดเก็บข้อมูล (เช่น ค่าเดินทางหลัก -> ค่าน้ำมัน, ค่ารถไฟฟ้า)',
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: onboardingState.selectedMainCategories.length,
                itemBuilder: (context, index) {
                  final parent = onboardingState.selectedMainCategories[index];
                  final subs = onboardingState.selectedSubCategories.where((s) => s.mainCategoryId == parent.id).toList();

                  return ExpansionTile(
                    title: Row(
                      children: [
                        Text(parent.emoji),
                        const SizedBox(width: 8),
                        Text(parent.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    children: [
                      if (subs.isEmpty)
                        const ListTile(title: Text('ไม่มีหมวดย่อยสำหรับหมวดหมู่นี้', style: TextStyle(fontSize: 13, color: Colors.grey)))
                      else
                        ...subs.map((sub) => ListTile(
                              leading: Text(sub.emoji, style: const TextStyle(fontSize: 18)),
                              title: Text(sub.name),
                            )),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showAddCustomSubCategory(onboardingState.selectedMainCategories),
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มหมวดย่อยกำหนดเอง'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      );
    }

    // --- Step 4: Wallets Setup ---
    Widget buildStep4() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ตั้งค่ากระเป๋าเงิน (Wallets)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'เลือกกระเป๋าเงินที่ใช้งานประจำ พร้อมกรอกยอดเงินเริ่มต้น (เช่น เงินสดหรือธนาคาร)',
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: onboardingState.selectedWallets.length,
                itemBuilder: (context, index) {
                  final wallet = onboardingState.selectedWallets[index];
                  final wColor = AppColors.fromHex(wallet.color);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: wColor.withOpacity(0.12),
                            child: Icon(
                              wallet.icon == 'account_balance' ? Icons.account_balance : Icons.payments,
                              color: wColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              wallet.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            height: 42,
                            child: TextField(
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: 'ยอดตั้งต้น',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onChanged: (val) {
                                final balance = double.tryParse(val) ?? 0.0;
                                notifier.updateWalletStartingBalance(wallet.id, balance);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showAddCustomWallet,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มกระเป๋าเงินใหม่'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      );
    }

    // --- Step 5: Summary Setup ---
    Widget buildStep5() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, size: 72, color: Colors.green),
            const SizedBox(height: 18),
            const Text(
              'ตั้งค่าพร้อมใช้งานแล้ว!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'กรุณาตรวจสอบข้อมูลตั้งต้นของคุณก่อนเริ่มใช้งาน',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    const Text('📁 หมวดหมู่หลักที่คุณเลือก', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: onboardingState.selectedMainCategories.map((c) => Chip(
                        avatar: Text(c.emoji),
                        label: Text(c.name, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text('🏦 กระเป๋าเงินของคุณ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    ...onboardingState.selectedWallets.map((w) => ListTile(
                      leading: Icon(
                        w.icon == 'account_balance' ? Icons.account_balance : Icons.payments,
                        color: AppColors.fromHex(w.color),
                      ),
                      dense: true,
                      title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text(
                        '${w.startingBalance.toStringAsFixed(2)} ฿',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Step to render switcher
    Widget getBody() {
      switch (onboardingState.currentStep) {
        case 1:
          return buildStep1();
        case 2:
          return buildStep2();
        case 3:
          return buildStep3();
        case 4:
          return buildStep4();
        case 5:
          return buildStep5();
        default:
          return buildStep1();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('สร้างระบบเงินของคุณ (${onboardingState.currentStep}/5)'),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Stepper bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: List.generate(5, (index) {
                final step = index + 1;
                final isPassed = step < onboardingState.currentStep;
                final isActive = step == onboardingState.currentStep;
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? theme.colorScheme.primary
                          : (isActive ? theme.colorScheme.primary.withOpacity(0.6) : Colors.grey.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(child: getBody()),
          
          // Navigation control buttons
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (onboardingState.currentStep > 1)
                  TextButton(
                    onPressed: () => notifier.setStep(onboardingState.currentStep - 1),
                    child: const Text('ย้อนกลับ', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                else
                  const SizedBox.shrink(),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onboardingState.isSaving
                      ? null
                      : () async {
                          if (onboardingState.currentStep < 5) {
                            // Validate and go to next step
                            if (onboardingState.currentStep == 2 && onboardingState.selectedMainCategories.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('กรุณาเลือกหรือเพิ่มหมวดหมู่หลักอย่างน้อย 1 รายการ')),
                              );
                              return;
                            }
                            if (onboardingState.currentStep == 4 && onboardingState.selectedWallets.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('กรุณาเลือกหรือเพิ่มกระเป๋าเงินอย่างน้อย 1 รายการ')),
                              );
                              return;
                            }
                            notifier.setStep(onboardingState.currentStep + 1);
                          } else {
                            // Finalize
                            await notifier.submitAndFinalize();
                          }
                        },
                  child: onboardingState.isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          onboardingState.currentStep == 5 ? 'เสร็จสิ้นและเริ่มใช้งาน' : 'ถัดไป',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
