import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../models/user_profile.dart';
import '../category/category_management_screen.dart';
import '../wallet/wallet_management_screen.dart';
import '../couple/couple_setup_screen.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/name_helper.dart';

final Map<String, Uint8List> _base64ImageCache = {};

Uint8List? _getCachedImageBytes(String? dataUrl) {
  if (dataUrl == null || !dataUrl.startsWith('data:image')) return null;
  if (_base64ImageCache.containsKey(dataUrl)) {
    return _base64ImageCache[dataUrl];
  }
  try {
    final bytes = base64Decode(dataUrl.split(',').last);
    _base64ImageCache[dataUrl] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _picker = ImagePicker();

  Future<void> _pickProfileImage(String currentNickname, UserProfile? userProfile, String userId) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        final profileRepo = ref.read(userProfileRepositoryProvider);
        final updatedProfile = UserProfile(
          id: userId,
          email: userProfile?.email ?? '',
          nickname: currentNickname.isNotEmpty ? currentNickname : (userProfile?.nickname ?? 'ผู้ใช้'),
          photoBase64: base64Str,
          coupleRoomId: userProfile?.coupleRoomId,
          createdAt: userProfile?.createdAt ?? DateTime.now(),
        );
        await profileRepo.saveProfile(updatedProfile);

        if (updatedProfile.coupleRoomId != null) {
          await ref.read(coupleRepositoryProvider).syncMemberInfo(
            updatedProfile.coupleRoomId!,
            userId,
            nickname: updatedProfile.nickname,
            email: updatedProfile.email,
            photoBase64: updatedProfile.photoBase64,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ อัปเดตรูปโปรไฟล์สำเร็จ!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('แนบรูปโปรไฟล์ไม่สำเร็จ: $e')),
        );
      }
    }
  }

  void _editProfileDialog(UserProfile? userProfile, String userId) {
    final nicknameController = TextEditingController(text: userProfile?.nickname ?? '');
    Uint8List? tempImageBytes;
    String? tempBase64Str = userProfile?.photoBase64;

    if (tempBase64Str != null && tempBase64Str.startsWith('data:image')) {
      try {
        tempImageBytes = base64Decode(tempBase64Str.split(',').last);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('✏️ แก้ไขข้อมูลโปรไฟล์', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar Preview & Change Button
              GestureDetector(
                onTap: () async {
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70,
                    maxWidth: 512,
                    maxHeight: 512,
                  );
                  if (pickedFile != null) {
                    final bytes = await pickedFile.readAsBytes();
                    final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                    setDialogState(() {
                      tempImageBytes = bytes;
                      tempBase64Str = base64Str;
                    });
                  }
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      backgroundImage: tempImageBytes != null
                          ? MemoryImage(tempImageBytes!)
                          : (tempBase64Str != null && tempBase64Str!.startsWith('http')
                              ? NetworkImage(tempBase64Str!) as ImageProvider
                              : null),
                      child: (tempImageBytes == null && (tempBase64Str == null || !tempBase64Str!.startsWith('http')))
                          ? Text(
                              userProfile?.nickname.isNotEmpty == true ? userProfile!.nickname.substring(0, 1) : '👤',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 28),
                            )
                          : null,
                    ),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กดที่รูปเพื่อเปลี่ยนรูปโปรไฟล์ 📸',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อเล่นของคุณในแอป',
                  hintText: 'กรอกชื่อเล่นที่ต้องการให้แสดงในสลิปและป้ายชื่อ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nicknameController.text.trim();
                if (newName.isNotEmpty) {
                  final profileRepo = ref.read(userProfileRepositoryProvider);
                  final updatedProfile = UserProfile(
                    id: userId,
                    email: userProfile?.email ?? '',
                    nickname: newName,
                    photoBase64: tempBase64Str,
                    coupleRoomId: userProfile?.coupleRoomId,
                    createdAt: userProfile?.createdAt ?? DateTime.now(),
                  );
                  await profileRepo.saveProfile(updatedProfile);
                  await ref.read(rawTransactionsProvider.notifier).updateCreatorNameForUser(userId, newName);

                  if (updatedProfile.coupleRoomId != null) {
                    await ref.read(coupleRepositoryProvider).syncMemberInfo(
                      updatedProfile.coupleRoomId!,
                      userId,
                      nickname: updatedProfile.nickname,
                      email: updatedProfile.email,
                      photoBase64: updatedProfile.photoBase64,
                    );
                  }

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✨ อัปเดตข้อมูลโปรไฟล์เรียบร้อยแล้ว!')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final authState = ref.watch(authNotifierProvider);
    final coupleRoomId = ref.watch(coupleRoomIdProvider);
    final coupleRoomAsync = ref.watch(coupleRoomProvider);
    final userProfile = ref.watch(userProfileProvider).value;

    final theme = Theme.of(context);
    final userId = authState.userId ?? '';

    final photoUrl = userProfile?.photoBase64;
    final profileImageBytes = _getCachedImageBytes(photoUrl);

    void confirmResetCategories() {
      ConfirmDialog.show(
        context,
        title: 'รีเซ็ตหมวดหมู่เริ่มต้น',
        content: 'คุณแน่ใจว่าต้องการรีเซ็ตโครงสร้างหมวดหมู่เป็นค่าเริ่มต้นหรือไม่?\n⚠️ การรีเซ็ตจะคืนค่าหมวดหมู่มาตรฐานตามระบบ และลบหมวดหมู่ย่อยที่คุณสร้างใหม่',
        confirmText: 'ยืนยันการรีเซ็ต',
        confirmColor: AppColors.primary,
        onConfirm: () async {
          await ref.read(mainCategoriesProvider.notifier).resetToDefault();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('รีเซ็ตหมวดหมู่สำเร็จแล้ว')));
          }
        },
      );
    }

    void confirmResetOnboarding() {
      ConfirmDialog.show(
        context,
        title: 'จำลอง Onboarding ใหม่',
        content: 'ต้องการรีเซ็ตสถานะแอปเพื่อกลับไปทำตามขั้นตอนแนะนำ Onboarding อีกครั้งหรือไม่?',
        confirmText: 'รีเซ็ตและออกระบบ',
        confirmColor: AppColors.expense,
        onConfirm: () async {
          await ref.read(onboardingCompletedProvider.notifier).resetOnboarding();
          await authNotifier.signOut();
        },
      );
    }

    void confirmLogout() {
      ConfirmDialog.show(
        context,
        title: 'ออกจากระบบ',
        content: 'คุณแน่ใจว่าต้องการออกจากระบบของผู้ใช้ปัจจุบันหรือไม่?',
        confirmText: 'ออกจากระบบ',
        confirmColor: AppColors.expense,
        onConfirm: () {
          authNotifier.signOut();
        },
      );
    }

    final partnerProfile = ref.watch(partnerProfileProvider).value;

    final partnerPhotoUrl = partnerProfile?.photoBase64;
    final partnerImageBytes = _getCachedImageBytes(partnerPhotoUrl);

    final String userName = NameHelper.resolveDisplayName(
      nickname: userProfile?.nickname,
      email: userProfile?.email,
      defaultFallback: 'ฉัน',
    );

    final String partnerName = NameHelper.resolveDisplayName(
      nickname: partnerProfile?.nickname,
      email: partnerProfile?.email,
      defaultFallback: coupleRoomAsync.value?.isFull == true ? 'แฟน 💕' : 'ยังไม่มีคู่รัก',
    );

    // Auto-sync current user's profile to couple_rooms document if changed or not yet stored
    if (userProfile != null && coupleRoomAsync.value != null) {
      final room = coupleRoomAsync.value!;
      final existingInfo = room.membersInfo[userProfile.id];
      if (existingInfo == null ||
          existingInfo['nickname'] != userProfile.nickname ||
          existingInfo['email'] != userProfile.email ||
          existingInfo['photoBase64'] != userProfile.photoBase64) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(coupleNotifierProvider.notifier).syncMyProfile(userProfile, room.id);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าระบบ'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Duo Couple Profile Card (👩‍❤️‍👨 Dual Avatars & Live Room Sync)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF2E1C2B),
                        const Color(0xFF221A30),
                        theme.colorScheme.surface,
                      ]
                    : [
                        AppColors.primary.withOpacity(0.14),
                        Colors.purple.withOpacity(0.06),
                        theme.colorScheme.surface,
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(isDark ? 0.4 : 0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top: Room & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💕 ห้องคู่รัก: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          Text(
                            coupleRoomAsync.value?.inviteCode ?? (coupleRoomId != null ? 'เชื่อมต่อแล้ว' : 'ยังไม่มีห้อง'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (coupleRoomAsync.value?.inviteCode != null)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: coupleRoomAsync.value!.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('คัดลอกโค้ดเชิญแล้ว: ${coupleRoomAsync.value!.inviteCode}')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2B2E42) : Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 12, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('คัดลอกโค้ด', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Center: Duo Avatars & Love Heart Bridge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Line Bridge connecting avatars
                    Positioned(
                      left: 60,
                      right: 60,
                      top: 34, // Vertical center of the 68px tall avatars
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.4),
                              Colors.purple.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // User 1: Me
                        Expanded(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => _pickProfileImage(userProfile?.nickname ?? '', userProfile, userId),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 34,
                                      backgroundColor: AppColors.primary.withOpacity(0.15),
                                      backgroundImage: profileImageBytes != null
                                          ? MemoryImage(profileImageBytes)
                                          : (photoUrl != null && photoUrl.startsWith('http')
                                              ? NetworkImage(photoUrl) as ImageProvider
                                              : null),
                                      child: (profileImageBytes == null && (photoUrl == null || !photoUrl.startsWith('http')))
                                          ? Text(
                                              userName.isNotEmpty ? userName.characters.first : '👤',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 24),
                                            )
                                          : null,
                                    ),
                                    CircleAvatar(
                                      radius: 11,
                                      backgroundColor: AppColors.primary,
                                      child: const Icon(Icons.camera_alt, size: 11, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      userName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.only(left: 4),
                                    icon: const Icon(Icons.edit, size: 14, color: Colors.grey),
                                    tooltip: 'แก้ไขชื่อ',
                                    onPressed: () => _editProfileDialog(userProfile, userId),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('ฉัน (โปรไฟล์นี้)', style: TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),

                        // Heart & Connection indicator
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Text('💖', style: TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              coupleRoomAsync.value?.isFull == true ? 'เชื่อมต่อแล้ว' : 'รอคู่รัก',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: coupleRoomAsync.value?.isFull == true ? Colors.green.shade700 : Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),

                        // User 2: Partner
                        Expanded(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CoupleSetupScreen()),
                                  );
                                },
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 34,
                                      backgroundColor: Colors.purple.withOpacity(0.15),
                                      backgroundImage: partnerImageBytes != null
                                          ? MemoryImage(partnerImageBytes)
                                          : (partnerPhotoUrl != null && partnerPhotoUrl.startsWith('http')
                                              ? NetworkImage(partnerPhotoUrl) as ImageProvider
                                              : null),
                                      child: (partnerImageBytes == null && (partnerPhotoUrl == null || !partnerPhotoUrl.startsWith('http')))
                                          ? Text(
                                              partnerName.isNotEmpty
                                                  ? partnerName.characters.first
                                                  : (coupleRoomAsync.value?.isFull == true ? 'แฟน' : '➕'),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple.shade700,
                                                fontSize: 22,
                                              ),
                                            )
                                          : null,
                                    ),
                                    if (coupleRoomAsync.value?.isFull == true)
                                      CircleAvatar(
                                        radius: 11,
                                        backgroundColor: Colors.green.shade600,
                                        child: const Icon(Icons.favorite, size: 11, color: Colors.white),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                partnerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  partnerProfile != null
                                      ? 'แฟน 💕'
                                      : (coupleRoomAsync.value?.isFull == true ? 'แฟน 💕' : 'กดเพื่อเชิญแฟน'),
                                  style: TextStyle(fontSize: 9, color: Colors.purple.shade700, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom: Manage Room Button
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CoupleSetupScreen()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.settings, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          coupleRoomId != null ? 'จัดการห้องคู่รัก' : 'เชื่อมต่อห้องคู่รัก 💕',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── SECTION 1: FINANCIAL CATEGORIES & WALLETS ───
          _buildSectionCard(
            context: context,
            title: 'หมวดหมู่ & กระเป๋าเงิน',
            children: [
              _buildSettingTile(
                context: context,
                icon: Icons.category_rounded,
                iconColor: const Color(0xFFFF6584),
                iconBgColor: const Color(0xFFFF6584).withOpacity(0.12),
                title: 'หมวดหมู่รายรับ-รายจ่าย',
                subtitle: 'จัดการหมวดและ Emoji',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
                  );
                },
              ),
              _buildSettingTile(
                context: context,
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF3182CE),
                iconBgColor: const Color(0xFF3182CE).withOpacity(0.12),
                title: 'กระเป๋าเงิน',
                subtitle: 'จัดการกระเป๋าเงินและยอดคงเหลือ',
                showDivider: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WalletManagementScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── SECTION 2: DISPLAY ───
          _buildSectionCard(
            context: context,
            title: 'การแสดงผล',
            children: [
              _buildSettingTile(
                context: context,
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                iconColor: Colors.purple.shade600,
                iconBgColor: Colors.purple.shade50,
                title: 'โหมดมืด',
                showDivider: false,
                trailing: Switch(
                  value: isDark,
                  activeColor: AppColors.primary,
                  onChanged: (val) => themeNotifier.toggleTheme(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── SECTION 3: DATA & ACCOUNT ───
          _buildSectionCard(
            context: context,
            title: 'ข้อมูลและการใช้งาน',
            children: [
              _buildSettingTile(
                context: context,
                icon: Icons.restart_alt_rounded,
                iconColor: Colors.orange.shade700,
                iconBgColor: Colors.orange.shade50,
                title: 'คืนค่าหมวดหมู่เริ่มต้น',
                subtitle: 'รีเซ็ตหมวดหมู่เป็นค่าเริ่มต้น',
                onTap: confirmResetCategories,
              ),
              _buildSettingTile(
                context: context,
                icon: Icons.assignment_ind_rounded,
                iconColor: Colors.teal.shade700,
                iconBgColor: Colors.teal.shade50,
                title: 'เริ่มต้นตั้งค่าใหม่',
                subtitle: 'ทำแบบสอบถามตั้งต้นใหม่อีกครั้ง',
                onTap: confirmResetOnboarding,
              ),
              _buildSettingTile(
                context: context,
                icon: Icons.logout_rounded,
                iconColor: AppColors.expense,
                iconBgColor: AppColors.expense.withOpacity(0.1),
                title: 'ออกจากระบบ',
                titleColor: AppColors.expense,
                showDivider: false,
                onTap: confirmLogout,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Footer Info
          Center(
            child: Text(
              'ผู้ใช้: ${userProfile?.email ?? authState.userId ?? "ผู้ใช้"} • Kapookluxx v1.0.0',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
    Color? titleColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveIconBg = isDark ? iconColor.withOpacity(0.20) : iconBgColor;
    final effectiveIconColor = isDark ? Color.lerp(iconColor, Colors.white, 0.25)! : iconColor;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: effectiveIconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: effectiveIconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? theme.colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else if (onTap != null)
                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.3)),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 62,
            endIndent: 14,
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
      ],
    );
  }
}
