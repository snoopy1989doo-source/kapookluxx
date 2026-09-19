import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/memory_ticket_options.dart';
import '../../models/memory_ticket.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/memory_ticket_provider.dart';

class MemoryTicketFormScreen extends ConsumerStatefulWidget {
  final MemoryTicket? ticket;

  const MemoryTicketFormScreen({super.key, this.ticket});

  @override
  ConsumerState<MemoryTicketFormScreen> createState() =>
      _MemoryTicketFormScreenState();
}

class _MemoryTicketFormScreenState
    extends ConsumerState<MemoryTicketFormScreen> {
  static const int _maxImages = 5;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();

  final List<_PendingMemoryImage> _pendingImages = [];
  final List<String> _existingImageUrls = [];
  final List<String> _removedImageUrls = [];

  late DateTime _memoryDate;
  late String _categoryKey;
  late String _emoji;
  late Color _color;
  bool _isSaving = false;

  int get _imageCount => _existingImageUrls.length + _pendingImages.length;

  @override
  void initState() {
    super.initState();
    final ticket = widget.ticket;
    _titleController.text = ticket?.title ?? '';
    _noteController.text = ticket?.note ?? '';
    _locationController.text = ticket?.location ?? '';
    _memoryDate = ticket?.memoryDate ?? DateTime.now();
    _categoryKey = ticket?.categoryKey ?? 'activity';
    _emoji = ticket?.emoji ?? '💕';
    _color = AppColors.fromHex(ticket?.colorHex ?? '#E91E63');
    _existingImageUrls.addAll(ticket?.imageUrls ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final remaining = _maxImages - _imageCount;
    if (remaining <= 0) {
      _showMessage('เพิ่มรูปได้สูงสุด $_maxImages รูปต่อ Ticket');
      return;
    }
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 76,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (files.isEmpty) return;
      final selected = files.take(remaining);
      final pending = <_PendingMemoryImage>[];
      for (final file in selected) {
        pending.add(
          _PendingMemoryImage(file: file, bytes: await file.readAsBytes()),
        );
      }
      if (!mounted) return;
      setState(() => _pendingImages.addAll(pending));
      if (files.length > remaining) {
        _showMessage(
            'เลือกไว้ ${files.length} รูป ระบบเพิ่มให้ $remaining รูป');
      }
    } catch (_) {
      _showMessage('ไม่สามารถเปิดคลังภาพได้');
    }
  }

  Future<void> _takePhoto() async {
    if (_imageCount >= _maxImages) {
      _showMessage('เพิ่มรูปได้สูงสุด $_maxImages รูปต่อ Ticket');
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 76,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      final pending = _PendingMemoryImage(
        file: file,
        bytes: await file.readAsBytes(),
      );
      if (mounted) setState(() => _pendingImages.add(pending));
    } catch (_) {
      _showMessage('ไม่สามารถเปิดกล้องได้');
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('ถ่ายรูปใหม่'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกจากคลังภาพ'),
                subtitle: const Text('เลือกได้หลายรูป'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _memoryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_memoryDate),
    );
    if (time == null || !mounted) return;
    setState(() {
      _memoryDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickCustomEmoji() async {
    final controller = TextEditingController(text: _emoji);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ใส่อีโมจิของคุณ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32),
          decoration: const InputDecoration(
            hintText: '💕',
            helperText: 'ใส่อีโมจิ 1 ตัว',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('ใช้'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) setState(() => _emoji = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageCount == 0) {
      _showMessage('เพิ่มรูปความทรงจำอย่างน้อย 1 รูป');
      return;
    }

    final roomId = ref.read(coupleRoomIdProvider);
    final userId = ref.read(authStateProvider).value;
    final profile = ref.read(userProfileProvider).value;
    if (roomId == null || userId == null) {
      _showMessage('ไม่พบห้องคู่รัก กรุณาเชื่อมต่อห้องก่อน');
      return;
    }

    setState(() => _isSaving = true);
    final repository = ref.read(memoryTicketRepositoryProvider);
    final id = widget.ticket?.id ?? const Uuid().v4();
    var uploadedUrls = <String>[];
    try {
      uploadedUrls = await repository.uploadImages(
        roomId: roomId,
        ticketId: id,
        images: _pendingImages.map((image) => image.file).toList(),
      );
      final now = DateTime.now();
      final ticket = MemoryTicket(
        id: id,
        title: _titleController.text.trim(),
        note: _noteController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        memoryDate: _memoryDate,
        categoryKey: _categoryKey,
        emoji: _emoji,
        colorHex: AppColors.toHex(_color),
        imageUrls: [..._existingImageUrls, ...uploadedUrls],
        createdByUserId: widget.ticket?.createdByUserId ?? userId,
        createdByName: widget.ticket?.createdByName ??
            (profile?.nickname.isNotEmpty == true
                ? profile!.nickname
                : 'สมาชิก'),
        createdAt: widget.ticket?.createdAt ?? now,
        updatedAt: now,
      );
      await repository.saveTicket(roomId, ticket);
      await repository.deleteImages(_removedImageUrls);
      if (!mounted) return;
      Navigator.pop(context, ticket);
    } catch (error) {
      await repository.deleteImages(uploadedUrls);
      if (!mounted) return;
      _showMessage('บันทึกไม่สำเร็จ กรุณาลองใหม่\n$error');
      setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = memoryTicketCategoryFor(_categoryKey);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticket == null
            ? 'สร้าง Memory Ticket'
            : 'แก้ไข Memory Ticket'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('บันทึก'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            children: [
              _buildTicketPreview(theme, category),
              const SizedBox(height: 20),
              _buildSectionTitle(
                  'รูปความทรงจำ', '$_imageCount/$_maxImages รูป'),
              const SizedBox(height: 10),
              SizedBox(
                height: 112,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (_imageCount < _maxImages) _buildAddImageButton(theme),
                    ..._existingImageUrls.asMap().entries.map(
                          (entry) =>
                              _buildNetworkImageTile(entry.key, entry.value),
                        ),
                    ..._pendingImages.asMap().entries.map(
                          (entry) =>
                              _buildPendingImageTile(entry.key, entry.value),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'ชื่อความทรงจำ',
                  hintText: 'เช่น ดูหนังเรื่องแรกด้วยกัน',
                  prefixIcon: Icon(Icons.favorite_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'กรุณาใส่ชื่อความทรงจำ'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'วันที่และเวลา',
                    prefixIcon: Icon(Icons.event_outlined),
                    suffixIcon: Icon(Icons.chevron_right_rounded),
                  ),
                  child: Text(
                    DateFormat('d MMMM y • HH:mm น.', 'th_TH')
                        .format(_memoryDate),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('ประเภทความทรงจำ', null),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: memoryTicketCategories.map((item) {
                  final selected = item.key == _categoryKey;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: Text(item.emoji),
                    label: Text(item.label),
                    onSelected: (_) => setState(() {
                      _categoryKey = item.key;
                      _emoji = item.emoji;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('อีโมจิบน Ticket', null),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  ...memoryTicketEmojis.map((emoji) {
                    final selected = emoji == _emoji;
                    return InkWell(
                      onTap: () => setState(() => _emoji = emoji),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? _color.withOpacity(0.18)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? _color
                                : theme.colorScheme.outlineVariant,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                  }),
                  InkWell(
                    onTap: _pickCustomEmoji,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: const Icon(Icons.add_reaction_outlined, size: 21),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('สีประจำ Ticket', null),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: memoryTicketColors.map((color) {
                  final selected = color.value == _color.value;
                  return InkWell(
                    onTap: () => setState(() => _color = color),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _locationController,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'สถานที่ (ไม่บังคับ)',
                  hintText: 'เช่น โรงหนัง ร้านอาหาร หรือจังหวัด',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'ข้อความความทรงจำ (ไม่บังคับ)',
                  hintText: 'เขียนสิ่งที่อยากจำจากวันนี้...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 74),
                    child: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.confirmation_number_outlined),
            label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก Memory Ticket'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketPreview(
    ThemeData theme,
    MemoryTicketCategory category,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color, _color.withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _color.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(_emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _titleController.text.trim().isEmpty
                      ? 'ความทรงจำของเรา'
                      : _titleController.text.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  DateFormat('d MMM y • HH:mm', 'th_TH').format(_memoryDate),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const RotatedBox(
            quarterTurns: 1,
            child: Text(
              'MEMORY TICKET',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String? trailing) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildAddImageButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: _showImageSourceSheet,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 100,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.35),
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined),
              SizedBox(height: 6),
              Text(
                'เพิ่มรูป',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkImageTile(int index, String url) {
    return _buildImageTile(
      Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined),
        ),
      ),
      onRemove: () {
        setState(() {
          final removed = _existingImageUrls.removeAt(index);
          _removedImageUrls.add(removed);
        });
      },
    );
  }

  Widget _buildPendingImageTile(int index, _PendingMemoryImage pending) {
    return _buildImageTile(
      Image.memory(pending.bytes, fit: BoxFit.cover),
      onRemove: () => setState(() => _pendingImages.removeAt(index)),
    );
  }

  Widget _buildImageTile(Widget image, {required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(width: 100, height: 112, child: image),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.62),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingMemoryImage {
  final XFile file;
  final Uint8List bytes;

  const _PendingMemoryImage({required this.file, required this.bytes});
}
