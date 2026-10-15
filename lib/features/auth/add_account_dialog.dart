import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/localization/app_locale.dart';
import '../../core/theme/tg_theme.dart';
import '../../core/widgets/tg_toast.dart';
import '../../data/models/tg_account.dart';

/// Модальный диалог добавления нового аккаунта Telegram (QR-код или номер телефона).
class AddAccountDialog extends StatefulWidget {
  const AddAccountDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddAccount',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim, secondaryAnim) {
        return const Center(child: AddAccountDialog());
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curve),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
    );
  }

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  int _tabIndex = 0; // 0: QR, 1: Phone
  int _phoneStep = 0; // 0: enter phone, 1: enter code

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  String _countryCode = '+7';
  bool _keepSignedIn = true;
  bool _isLoading = false;

  final List<Map<String, String>> _countries = [
    {'flag': '🇷🇺', 'name': 'Russia', 'code': '+7'},
    {'flag': '🇺🇸', 'name': 'USA', 'code': '+1'},
    {'flag': '🇵🇭', 'name': 'Philippines', 'code': '+63'},
    {'flag': '🇧🇾', 'name': 'Belarus', 'code': '+375'},
    {'flag': '🇰🇿', 'name': 'Kazakhstan', 'code': '+7'},
    {'flag': '🇩🇪', 'name': 'Germany', 'code': '+49'},
    {'flag': '🇬🇧', 'name': 'UK', 'code': '+44'},
    {'flag': '🇺🇿', 'name': 'Uzbekistan', 'code': '+998'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onNextPhone() {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) {
      TgToast.show(context, tr('phone_number_label'));
      return;
    }
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _phoneStep = 1;
      });
    });
  }

  void _onCompleteLogin() {
    final phone = '$_countryCode ${_phoneController.text.trim()}';
    final customName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'User ${phone.substring(phone.length > 4 ? phone.length - 4 : 0)}';

    final initials = customName.trim().isNotEmpty
        ? customName.trim().substring(0, customName.trim().length >= 2 ? 2 : 1).toUpperCase()
        : 'TG';

    final newAcc = TgAccount(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      name: customName,
      phone: phone,
      username: '@${customName.toLowerCase().replaceAll(' ', '_')}',
      bio: 'Telegram Account',
      avatarEmoji: initials,
      avatarColor: const Color(0xFF6B58C9),
      unreadBadge: 0,
      isOnline: true,
    );

    AccountManager.instance.addAccount(newAcc);
    TgToast.show(context, '✓ ${tr('accounts')}: $customName');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 440,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: Tg.sidebar,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Tg.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Шапка диалога
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Text(
                    tr('add_account_dialog_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Tg.textDim, size: 20),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Переключатель вкладок QR / Номер телефона
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Tg.field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _tabButton(
                        title: tr('login_qr_tab'),
                        icon: Icons.qr_code_rounded,
                        selected: _tabIndex == 0,
                        onTap: () => setState(() => _tabIndex = 0),
                      ),
                    ),
                    Expanded(
                      child: _tabButton(
                        title: tr('login_phone_tab'),
                        icon: Icons.phone_android_rounded,
                        selected: _tabIndex == 1,
                        onTap: () => setState(() => _tabIndex = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Контент вкладки
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: _tabIndex == 0 ? _buildQrTab() : _buildPhoneTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2B5278) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Tg.textDim),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : Tg.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrTab() {
    return Column(
      children: [
        const SizedBox(height: 10),
        // QR-код контейнер
        Container(
          width: 210,
          height: 210,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: QrImageView(
            data: 'tg://login?token=amos_session_${DateTime.now().millisecondsSinceEpoch}',
            version: QrVersions.auto,
            size: 186.0,
            embeddedImage: const AssetImage('assets/images/tg_icon.png'),
            embeddedImageStyle: const QrEmbeddedImageStyle(
              size: Size(36, 36),
            ),
          ),
        ),

        const SizedBox(height: 22),

        // Инструкция по шагам
        _buildInstructionStep('1', tr('qr_step_1')),
        const SizedBox(height: 10),
        _buildInstructionStep('2', tr('qr_step_2')),
        const SizedBox(height: 10),
        _buildInstructionStep('3', tr('qr_step_3')),

        const SizedBox(height: 20),

        TextButton(
          onPressed: () => setState(() => _tabIndex = 1),
          child: Text(
            tr('login_by_phone_btn'),
            style: const TextStyle(color: Color(0xFF55A5EB), fontSize: 13.5),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFF2B5278),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Tg.text, fontSize: 13, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneTab() {
    if (_phoneStep == 1) {
      return _buildCodeStep();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          tr('country_label'),
          style: const TextStyle(color: Tg.textDim, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: _countryCode,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF212D3B),
            items: _countries.map((c) {
              return DropdownMenuItem<String>(
                value: c['code']!,
                child: Row(
                  children: [
                    Text(c['flag']!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(c['name']!, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                    const Spacer(),
                    Text(c['code']!, style: const TextStyle(color: Tg.textDim, fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _countryCode = val);
            },
          ),
        ),

        const SizedBox(height: 16),

        Text(
          tr('phone_number_label'),
          style: const TextStyle(color: Tg.textDim, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  _countryCode,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Container(width: 1, height: 22, color: Colors.white.withValues(alpha: 0.1)),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: tr('phone_number_hint'),
                    hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Text(
          tr('first_name'),
          style: const TextStyle(color: Tg.textDim, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'e.g. Sergei',
              hintStyle: TextStyle(color: Tg.textFaint, fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Checkbox(
              value: _keepSignedIn,
              activeColor: const Color(0xFF55A5EB),
              onChanged: (v) => setState(() => _keepSignedIn = v ?? true),
            ),
            Text(
              tr('keep_signed_in'),
              style: const TextStyle(color: Tg.text, fontSize: 13),
            ),
          ],
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F6FA8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _onNextPhone,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tr('next_btn'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          tr('enter_code_title'),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          '${tr('code_sent_hint')} ($_countryCode ${_phoneController.text.trim()})',
          style: const TextStyle(color: Tg.textDim, fontSize: 12.5),
        ),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
            decoration: InputDecoration(
              hintText: '• • • • •',
              hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 16, letterSpacing: 2),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F6FA8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: _onCompleteLogin,
            child: Text(
              tr('verify_and_login'),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: () => setState(() => _phoneStep = 0),
            child: Text(
              '← ${tr('cancel')}',
              style: const TextStyle(color: Tg.textDim, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
