import 'package:flutter/material.dart';

import '../../core/theme/tg_theme.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../core/widgets/tg_toast.dart';
import '../../data/models/tg_account.dart';
import '../ai_copilot/models/ai_settings_model.dart';

class EditAccountDialog extends StatefulWidget {
  const EditAccountDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const EditAccountDialog(),
    );
  }

  @override
  State<EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<EditAccountDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final cur = AccountManager.instance.currentAccount.value;
    final parts = cur.name.split(' ');
    _nameController = TextEditingController(text: parts.first);
    _lastNameController = TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    _bioController = TextEditingController(text: cur.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _save() {
    final fn = _nameController.text.trim();
    final ln = _lastNameController.text.trim();
    final fullName = ln.isNotEmpty ? '$fn $ln' : fn;
    AccountManager.instance.updateCurrentAccount(
      name: fullName.isNotEmpty ? fullName : 'Natalie',
      bio: _bioController.text.trim(),
    );
    Navigator.of(context).pop();
    TgToast.show(context, '✅ Профиль успешно обновлен');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ValueListenableBuilder<TgAccount>(
        valueListenable: AccountManager.instance.currentAccount,
        builder: (context, acc, _) {
          return Container(
            width: 440,
            constraints: const BoxConstraints(maxHeight: 740),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        _buildNameCard(),
                        const SizedBox(height: 14),
                        _buildBioCard(),
                        const SizedBox(height: 14),
                        _buildYourInfoCard(acc),
                        const SizedBox(height: 14),
                        _buildAutomationCard(context),
                        const SizedBox(height: 14),
                        _buildAccountsCard(context, acc),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Tg.textDim, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Tg.text,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Tg.accent, size: 24),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _buildNameCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2B38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your name', style: TextStyle(fontSize: 12, color: Color(0xFF55A5EB), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'First name',
              hintStyle: TextStyle(color: Tg.textDim),
            ),
          ),
          Divider(height: 16, color: Colors.white.withValues(alpha: 0.06)),
          TextField(
            controller: _lastNameController,
            style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Last name (optional)',
              hintStyle: TextStyle(color: Tg.textDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2B38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextField(
                  controller: _bioController,
                  maxLength: 70,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Bio',
                    hintStyle: TextStyle(color: Tg.textDim),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Text(
                '${70 - _bioController.text.length}',
                style: const TextStyle(fontSize: 12, color: Tg.textDim),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('A few words about you.', style: TextStyle(fontSize: 12, color: Tg.textDim)),
        ],
      ),
    );
  }

  Widget _buildYourInfoCard(TgAccount acc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2B38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Info', style: TextStyle(fontSize: 12, color: Color(0xFF55A5EB), fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                child: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acc.phone, style: const TextStyle(fontSize: 14.5, color: Colors.white, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    const Text('Tap to change phone number', style: TextStyle(fontSize: 11.5, color: Tg.textDim)),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 20, color: Colors.white.withValues(alpha: 0.06)),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFFFFA000), shape: BoxShape.circle),
                child: const Icon(Icons.alternate_email_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acc.username, style: const TextStyle(fontSize: 14.5, color: Colors.white, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    const Text('Username', style: TextStyle(fontSize: 11.5, color: Tg.textDim)),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 20, color: Colors.white.withValues(alpha: 0.06)),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFF29B6F6), shape: BoxShape.circle),
                child: const Icon(Icons.cake_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Birthday', style: TextStyle(fontSize: 14.5, color: Colors.white, fontWeight: FontWeight.w500)),
                    SizedBox(height: 2),
                    Text('Only your contacts can see your birthday.', style: TextStyle(fontSize: 11.5, color: Tg.textDim)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Tg.textFaint, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2B38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFFFF9800), shape: BoxShape.circle),
                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Personal channel', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              const Text('Add', style: TextStyle(fontSize: 13, color: Color(0xFF55A5EB), fontWeight: FontWeight.w600)),
            ],
          ),
          Divider(height: 20, color: Colors.white.withValues(alpha: 0.06)),
          ValueListenableBuilder<AiSettings>(
            valueListenable: AiSettingsStore.instance.settings,
            builder: (context, aiSettings, _) {
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF8774E1), Color(0xFFAB47BC)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Chat Automation', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(color: const Color(0xFF8774E1), borderRadius: BorderRadius.circular(6)),
                              child: const Text('NEW', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('Add a bot to answer messages on your behalf.', style: TextStyle(fontSize: 11.5, color: Tg.textDim)),
                      ],
                    ),
                  ),
                  Switch(
                    value: aiSettings.autoPilotEnabled,
                    activeThumbColor: const Color(0xFF8774E1),
                    onChanged: (val) {
                      AiSettingsStore.instance.settings.value = aiSettings.copyWith(autoPilotEnabled: val);
                      TgToast.show(context, val ? '🚀 Автоответчик включен' : 'Автоответчик отключен');
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsCard(BuildContext context, TgAccount current) {
    final all = AccountManager.instance.accounts.value;
    final otherAccounts = all.where((a) => a.id != current.id).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2B38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () {
              TgToast.show(context, 'Добавление нового аккаунта');
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF55A5EB), size: 22),
                  SizedBox(width: 14),
                  Text(
                    'Add Account',
                    style: TextStyle(fontSize: 14.5, color: Color(0xFF55A5EB), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (otherAccounts.isNotEmpty)
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          ...otherAccounts.map((acc) {
            return InkWell(
              onTap: () {
                AccountManager.instance.switchAccount(acc.id);
                TgToast.show(context, 'Переключено на аккаунт: ${acc.name}');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    TgAvatar(
                      emoji: acc.avatarEmoji,
                      color: acc.avatarColor,
                      imagePath: acc.avatarPath,
                      size: 32,
                      fontSize: 14,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        acc.name,
                        style: const TextStyle(fontSize: 14.5, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (acc.unreadBadge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F6FA8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${acc.unreadBadge}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: Tg.textFaint, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
