import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/memory_ticket_options.dart';
import '../../models/memory_ticket.dart';
import '../../providers/memory_ticket_provider.dart';
import 'memory_ticket_detail_screen.dart';
import 'memory_ticket_form_screen.dart';

class MemoryTicketGalleryScreen extends ConsumerStatefulWidget {
  const MemoryTicketGalleryScreen({super.key});

  @override
  ConsumerState<MemoryTicketGalleryScreen> createState() =>
      _MemoryTicketGalleryScreenState();
}

class _MemoryTicketGalleryScreenState
    extends ConsumerState<MemoryTicketGalleryScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticketsAsync = ref.watch(memoryTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Memory Ticket'),
            Text(
              'อัลบั้มความทรงจำของเราสองคน',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(theme, error),
        data: (tickets) {
          final filtered = _selectedCategory == null
              ? tickets
              : tickets
                  .where((ticket) => ticket.categoryKey == _selectedCategory)
                  .toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(theme, tickets)),
              SliverToBoxAdapter(child: _buildFilters(theme)),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    theme,
                    hasAnyTickets: tickets.isNotEmpty,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.71,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _MemoryTicketCard(
                        ticket: filtered[index],
                        onTap: () => _openDetail(filtered[index]),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTicket,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('เพิ่มความทรงจำ'),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, List<MemoryTicket> tickets) {
    final thisYearCount = tickets
        .where((ticket) => ticket.memoryDate.year == DateTime.now().year)
        .length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandStart, AppColors.brandEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandStart.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เรื่องราวของเราสองคน',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tickets.isEmpty
                      ? 'เริ่มเก็บช่วงเวลาดี ๆ ไว้ด้วยกัน'
                      : '${tickets.length} ความทรงจำ • ปีนี้ $thisYearCount ครั้ง',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const Text('💕', style: TextStyle(fontSize: 25)),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return SizedBox(
      height: 42,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: _selectedCategory == null,
              showCheckmark: false,
              avatar: const Icon(Icons.grid_view_rounded, size: 16),
              label: const Text('ทั้งหมด'),
              onSelected: (_) => setState(() => _selectedCategory = null),
            ),
          ),
          ...memoryTicketCategories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _selectedCategory == category.key,
                showCheckmark: false,
                avatar: Text(category.emoji),
                label: Text(category.label),
                onSelected: (_) => setState(
                  () => _selectedCategory = category.key,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, {required bool hasAnyTickets}) {
    final category = _selectedCategory == null
        ? null
        : memoryTicketCategoryFor(_selectedCategory!);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 18, 32, 110),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
              child: Text(
                category?.emoji ?? '🎟️',
                style: const TextStyle(fontSize: 42),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasAnyTickets
                  ? 'ยังไม่มีความทรงจำประเภท${category?.label ?? ''}'
                  : 'ยังไม่มี Memory Ticket',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 7),
            Text(
              hasAnyTickets
                  ? 'เลือกประเภทอื่น หรือสร้าง Ticket ใหม่ได้เลย'
                  : 'เก็บรูป วันที่ และเรื่องราวของกิจกรรมที่ทำร่วมกันไว้ในที่เดียว',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _createTicket,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('สร้าง Ticket แรก'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'โหลดความทรงจำไม่สำเร็จ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'กรุณาตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(memoryTicketsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTicket() async {
    await Navigator.push<MemoryTicket>(
      context,
      MaterialPageRoute(builder: (_) => const MemoryTicketFormScreen()),
    );
  }

  Future<void> _openDetail(MemoryTicket ticket) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoryTicketDetailScreen(ticket: ticket),
      ),
    );
  }
}

class _MemoryTicketCard extends StatelessWidget {
  final MemoryTicket ticket;
  final VoidCallback onTap;

  const _MemoryTicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.fromHex(ticket.colorHex);
    final category = memoryTicketCategoryFor(ticket.categoryKey);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (ticket.imageUrls.isNotEmpty)
                      Image.network(
                        ticket.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: color.withOpacity(0.12),
                          alignment: Alignment.center,
                          child: Text(
                            ticket.emoji,
                            style: const TextStyle(fontSize: 38),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: color.withOpacity(0.12),
                        alignment: Alignment.center,
                        child: Text(
                          ticket.emoji,
                          style: const TextStyle(fontSize: 38),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.55),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 9,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${category.emoji} ${category.label}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (ticket.imageUrls.length > 1)
                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.48),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '+${ticket.imageUrls.length - 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 9,
                      child: Text(
                        ticket.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 13, color: color),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormat('d MMM y', 'th_TH')
                                .format(ticket.memoryDate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ticket.location?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              ticket.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
