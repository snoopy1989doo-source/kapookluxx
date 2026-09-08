import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../../models/transaction_item.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/category/color_picker_dialog.dart';
import '../../widgets/category/emoji_picker_dialog.dart';
import 'category_management_screen.dart';

class CategorySelection {
  final String mainCategoryId;
  final String subCategoryId;

  const CategorySelection({
    required this.mainCategoryId,
    required this.subCategoryId,
  });
}

class CategoryPickerScreen extends ConsumerStatefulWidget {
  final bool isIncome;
  final String? selectedMainCategoryId;
  final String? selectedSubCategoryId;

  const CategoryPickerScreen({
    super.key,
    required this.isIncome,
    this.selectedMainCategoryId,
    this.selectedSubCategoryId,
  });

  @override
  ConsumerState<CategoryPickerScreen> createState() =>
      _CategoryPickerScreenState();
}

class _CategoryPickerScreenState extends ConsumerState<CategoryPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesTransactionType(MainCategory category) {
    final id = category.id.toLowerCase();
    final name = category.name.toLowerCase();
    final isIncomeCategory = id.contains('income') ||
        name.contains('รายรับ') ||
        name.contains('เงินเดือน');
    return widget.isIncome ? isIncomeCategory : !isIncomeCategory;
  }

  String _displayName(String name) => name.split(' (').first.trim();

  List<SubCategory> _frequentCategories(
    List<SubCategory> available,
    List<TransactionItem> transactions,
  ) {
    final availableIds = available.map((category) => category.id).toSet();
    final counts = <String, int>{};
    final latestUse = <String, DateTime>{};

    for (final transaction in transactions) {
      if (transaction.type != (widget.isIncome ? 'income' : 'expense') ||
          !availableIds.contains(transaction.subCategoryId)) {
        continue;
      }
      counts.update(transaction.subCategoryId, (value) => value + 1,
          ifAbsent: () => 1);
      final previous = latestUse[transaction.subCategoryId];
      if (previous == null || transaction.date.isAfter(previous)) {
        latestUse[transaction.subCategoryId] = transaction.date;
      }
    }

    final frequent =
        available.where((category) => counts.containsKey(category.id)).toList()
          ..sort((a, b) {
            final countCompare = counts[b.id]!.compareTo(counts[a.id]!);
            if (countCompare != 0) return countCompare;
            return latestUse[b.id]!.compareTo(latestUse[a.id]!);
          });
    return frequent.take(8).toList();
  }

  void _select(SubCategory category) {
    Navigator.of(context).pop(
      CategorySelection(
        mainCategoryId: category.mainCategoryId,
        subCategoryId: category.id,
      ),
    );
  }

  Future<void> _openManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CategoryManagementScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _addMainCategory() async {
    final categories = ref.read(mainCategoriesProvider);
    final nameController = TextEditingController();
    var emoji = widget.isIncome ? '💰' : '📁';
    var color = widget.isIncome ? AppColors.income : AppColors.primary;

    final created = await showDialog<MainCategory>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final trimmedName = nameController.text.trim();
          final isDuplicate = categories.any(
            (category) =>
                category.name.trim().toLowerCase() == trimmedName.toLowerCase(),
          );
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('เพิ่มหมวดหมู่หลัก'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'ชื่อหมวดหมู่',
                    hintText: widget.isIncome
                        ? 'เช่น รายได้เสริม'
                        : 'เช่น สัตว์เลี้ยง',
                    errorText: isDuplicate ? 'มีชื่อหมวดหมู่นี้แล้ว' : null,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _DialogChoice(
                      label: 'อีโมจิ',
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      onTap: () => EmojiPickerDialog.show(context, (value) {
                        setDialogState(() => emoji = value);
                      }),
                    ),
                    _DialogChoice(
                      label: 'สี',
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      onTap: () => ColorPickerDialog.show(context, (value) {
                        setDialogState(() => color = value);
                      }),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: trimmedName.isEmpty || isDuplicate
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop(
                          MainCategory(
                            id: widget.isIncome
                                ? 'main_cat_income_${const Uuid().v4()}'
                                : 'main_cat_${const Uuid().v4()}',
                            name: trimmedName,
                            color: AppColors.toHex(color),
                            emoji: emoji,
                            order: categories.length,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                      },
                child: const Text('เพิ่ม'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();

    if (created == null || !mounted) return;
    try {
      await ref.read(mainCategoriesProvider.notifier).addCategory(created);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่ม “${_displayName(created.name)}” แล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่มหมวดหมู่ไม่สำเร็จ: $error')),
        );
      }
    }
  }

  Future<void> _addSubCategory(MainCategory parent) async {
    final subCategories = ref.read(subCategoriesProvider);
    final nameController = TextEditingController();
    var emoji = '📄';

    final created = await showDialog<SubCategory>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final trimmedName = nameController.text.trim();
          final isDuplicate = subCategories.any(
            (category) =>
                category.mainCategoryId == parent.id &&
                category.name.trim().toLowerCase() == trimmedName.toLowerCase(),
          );
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('เพิ่มใน ${_displayName(parent.name)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'ชื่อหมวดหมู่ย่อย',
                    hintText: 'เช่น ค่าอาหารสัตว์',
                    errorText:
                        isDuplicate ? 'มีชื่อหมวดหมู่นี้ในกลุ่มแล้ว' : null,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _DialogChoice(
                    label: 'อีโมจิ',
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    onTap: () => EmojiPickerDialog.show(context, (value) {
                      setDialogState(() => emoji = value);
                    }),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: trimmedName.isEmpty || isDuplicate
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop(
                          SubCategory(
                            id: 'sub_cat_${const Uuid().v4()}',
                            mainCategoryId: parent.id,
                            name: trimmedName,
                            emoji: emoji,
                            color: parent.color,
                            order: subCategories
                                .where((category) =>
                                    category.mainCategoryId == parent.id)
                                .length,
                          ),
                        );
                      },
                child: const Text('เพิ่มและเลือก'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();

    if (created == null || !mounted) return;
    try {
      await ref.read(subCategoriesProvider.notifier).addSubCategory(created);
      if (mounted) _select(created);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่มหมวดหมู่ไม่สำเร็จ: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allMainCategories = ref.watch(mainCategoriesProvider);
    final allSubCategories = ref.watch(subCategoriesProvider);
    final transactions = ref.watch(rawTransactionsProvider);
    final mainCategories = allMainCategories
        .where(_matchesTransactionType)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final mainCategoryIds =
        mainCategories.map((category) => category.id).toSet();
    final availableSubCategories = allSubCategories
        .where((category) => mainCategoryIds.contains(category.mainCategoryId))
        .toList();
    final frequent = _query.isEmpty
        ? _frequentCategories(availableSubCategories, transactions)
        : <SubCategory>[];
    final normalizedQuery = _query.trim().toLowerCase();

    final visibleGroups = <MapEntry<MainCategory, List<SubCategory>>>[];
    for (final mainCategory in mainCategories) {
      final mainMatches = _displayName(mainCategory.name)
          .toLowerCase()
          .contains(normalizedQuery);
      final subCategories = availableSubCategories
          .where((category) => category.mainCategoryId == mainCategory.id)
          .where((category) =>
              normalizedQuery.isEmpty ||
              mainMatches ||
              _displayName(category.name)
                  .toLowerCase()
                  .contains(normalizedQuery))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      if (subCategories.isNotEmpty ||
          (normalizedQuery.isEmpty || mainMatches)) {
        visibleGroups.add(MapEntry(mainCategory, subCategories));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกหมวดหมู่'),
        actions: [
          TextButton.icon(
            onPressed: _openManagement,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('จัดการ'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'ค้นหาหมวดหมู่',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'ล้างคำค้นหา',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: visibleGroups.isEmpty && frequent.isEmpty
                ? _EmptyCategorySearch(
                    hasQuery: normalizedQuery.isNotEmpty,
                    onAddMainCategory: _addMainCategory,
                  )
                : CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      if (frequent.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: _SectionTitle(
                            title: 'ใช้บ่อย',
                            icon: Icons.star_rounded,
                          ),
                        ),
                        _categoryGrid(
                          frequent,
                          allMainCategories,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      ],
                      for (final group in visibleGroups) ...[
                        SliverToBoxAdapter(
                          child: _MainCategoryHeader(
                            category: group.key,
                            displayName: _displayName(group.key.name),
                            selected:
                                widget.selectedMainCategoryId == group.key.id,
                            onAdd: () => _addSubCategory(group.key),
                          ),
                        ),
                        if (group.value.isNotEmpty)
                          _categoryGrid(group.value, allMainCategories)
                        else
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                              child: Text(
                                'ยังไม่มีหมวดหมู่ย่อย',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _addSubCategory(group.key),
                                icon: const Icon(
                                    Icons.add_circle_outline_rounded),
                                label: const Text('เพิ่มหมวดในกลุ่มนี้'),
                              ),
                            ),
                          ),
                        ),
                      ],
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          child: OutlinedButton.icon(
                            onPressed: _addMainCategory,
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('เพิ่มหมวดหมู่หลัก'),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _categoryGrid(
    List<SubCategory> categories,
    List<MainCategory> mainCategories,
  ) {
    final mainById = {
      for (final category in mainCategories) category.id: category,
    };
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 110,
          mainAxisExtent: 108,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = categories[index];
            final parent = mainById[category.mainCategoryId];
            return _CategoryTile(
              category: category,
              displayName: _displayName(category.name),
              color: parent == null
                  ? AppColors.fromHex(category.color)
                  : AppColors.fromHex(parent.color),
              selected: widget.selectedSubCategoryId == category.id,
              onTap: () => _select(category),
            );
          },
          childCount: categories.length,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MainCategoryHeader extends StatelessWidget {
  final MainCategory category;
  final String displayName;
  final bool selected;
  final VoidCallback onAdd;

  const _MainCategoryHeader({
    required this.category,
    required this.displayName,
    required this.selected,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.fromHex(category.color);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(18, 13, 8, 13),
      decoration: BoxDecoration(
        color: color.withOpacity(theme.brightness == Brightness.dark
            ? (selected ? 0.26 : 0.18)
            : (selected ? 0.14 : 0.09)),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: Row(
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'เพิ่มหมวดในกลุ่มนี้',
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final SubCategory category;
  final String displayName;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.displayName,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'เลือก $displayName',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(
                        theme.brightness == Brightness.dark ? 0.24 : 0.15,
                      ),
                      border: Border.all(
                        color: selected ? color : color.withOpacity(0.28),
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    child: Text(category.emoji,
                        style: const TextStyle(fontSize: 27)),
                  ),
                  if (selected)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 21,
                        height: 21,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.2,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? color : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogChoice extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback onTap;

  const _DialogChoice({
    required this.label,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            child,
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _EmptyCategorySearch extends StatelessWidget {
  final bool hasQuery;
  final VoidCallback onAddMainCategory;

  const _EmptyCategorySearch({
    required this.hasQuery,
    required this.onAddMainCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.category_outlined,
              size: 54,
              color: theme.colorScheme.primary.withOpacity(0.55),
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'ไม่พบหมวดหมู่ที่ค้นหา'
                  : 'ยังไม่มีหมวดหมู่สำหรับรายการนี้',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAddMainCategory,
                icon: const Icon(Icons.add_rounded),
                label: const Text('เพิ่มหมวดหมู่หลัก'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
