import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/memory_ticket_options.dart';
import '../../models/memory_ticket.dart';
import '../../providers/couple_provider.dart';
import '../../providers/memory_ticket_provider.dart';
import 'memory_ticket_form_screen.dart';

class MemoryTicketDetailScreen extends ConsumerStatefulWidget {
  final MemoryTicket ticket;

  const MemoryTicketDetailScreen({super.key, required this.ticket});

  @override
  ConsumerState<MemoryTicketDetailScreen> createState() =>
      _MemoryTicketDetailScreenState();
}

class _MemoryTicketDetailScreenState
    extends ConsumerState<MemoryTicketDetailScreen> {
  late MemoryTicket _ticket;
  final _pageController = PageController();
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    final result = await Navigator.push<MemoryTicket>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoryTicketFormScreen(ticket: _ticket),
      ),
    );
    if (result != null && mounted) setState(() => _ticket = result);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.expense),
        title: const Text('ลบ Memory Ticket?'),
        content: const Text(
          'รูปและข้อความใน Ticket นี้จะถูกลบออกจากห้องคู่รัก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final roomId = ref.read(coupleRoomIdProvider);
    if (roomId == null) return;
    try {
      await ref
          .read(memoryTicketRepositoryProvider)
          .deleteTicket(roomId, _ticket);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบไม่สำเร็จ กรุณาลองใหม่\n$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.fromHex(_ticket.colorHex);
    final category = memoryTicketCategoryFor(_ticket.categoryKey);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') _edit();
              if (value == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('แก้ไข'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: AppColors.expense),
                  title: Text('ลบ', style: TextStyle(color: AppColors.expense)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 430,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_ticket.imageUrls.isEmpty)
                    Container(
                      color: color.withOpacity(0.15),
                      alignment: Alignment.center,
                      child: Text(
                        _ticket.emoji,
                        style: const TextStyle(fontSize: 72),
                      ),
                    )
                  else
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _ticket.imageUrls.length,
                      onPageChanged: (index) =>
                          setState(() => _pageIndex = index),
                      itemBuilder: (_, index) => Image.network(
                        _ticket.imageUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: color.withOpacity(0.12),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.45),
                          Colors.transparent,
                          Colors.black.withOpacity(0.72),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${category.emoji} ${category.label}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_ticket.imageUrls.length > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '${_pageIndex + 1}/${_ticket.imageUrls.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _ticket.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            height: 1.15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildTicketCard(theme, color, category),
                if (_ticket.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'เรื่องราวของวันนี้',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: color.withOpacity(0.18)),
                    ),
                    child: Text(
                      _ticket.note,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'บันทึกโดย ${_ticket.createdByName} • ${DateFormat('d MMM y', 'th_TH').format(_ticket.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(
    ThemeData theme,
    Color color,
    MemoryTicketCategory category,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Text(
                    _ticket.emoji,
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEMORY TICKET',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        DateFormat('EEEE d MMMM y', 'th_TH')
                            .format(_ticket.memoryDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${DateFormat('HH:mm').format(_ticket.memoryDate)} น. • ${category.label}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 12,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _DashedLinePainter(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  child: const SizedBox(height: 1),
                ),
              ),
              Container(
                width: 12,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          if (_ticket.location?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _ticket.location!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const gap = 4.0;
    var startX = 0.0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset((startX + dashWidth).clamp(0, size.width), 0),
        paint,
      );
      startX += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
