import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/localization/app_locale.dart';
import '../../core/theme/tg_theme.dart';
import '../../data/tdlib/tdlib_service.dart';
import '../../state/app_state.dart';

/// Экран авторизации в Telegram: QR-код (по умолчанию) / Телефон / 2FA.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  bool _preferPhone = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(AuthPhase phase) {
    final service = TdlibService.instance;
    final value = _controller.text.trim();
    if (value.isEmpty || _busy) return;
    setState(() => _busy = true);
    switch (phase) {
      case AuthPhase.waitPhone:
        service.sendPhoneNumber(value);
      case AuthPhase.waitCode:
        service.sendCode(value);
      case AuthPhase.waitPassword:
        service.sendPassword(value);
      default:
        break;
    }
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _busy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TdlibService.instance.phase,
        TdlibService.instance.errorText,
        TdlibService.instance.qrLink,
        TdlibService.instance.codeDeliveryHint,
        TdlibService.instance.passwordHint,
      ]),
      builder: (context, _) {
        final service = TdlibService.instance;
        final phase = service.phase.value;
        final error = service.errorText.value;
        final qrLink = service.qrLink.value;
        final codeHint = service.codeDeliveryHint.value;
        final passwordHint = service.passwordHint.value;

        return Scaffold(
          backgroundColor: Tg.chatBg,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Tg.sidebar,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Tg.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Логотип
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/tg_icon.png',
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 76,
                            height: 76,
                            decoration: const BoxDecoration(
                              gradient: Tg.accentGradient,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.send_rounded, size: 36, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'TellMeMore TG',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Tg.text,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Ошибка
                      if (error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Tg.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Tg.danger.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Tg.danger),
                          ),
                        ),
                      ],

                      // Контент в зависимости от фазы
                      if (phase == AuthPhase.connecting || phase == AuthPhase.idle) ...[
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Tg.accent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('connecting_tg'),
                          style: const TextStyle(fontSize: 14, color: Tg.textDim),
                        ),
                      ] else if (phase == AuthPhase.waitQr && !_preferPhone && qrLink != null) ...[
                        // Вход по QR-коду
                        const SizedBox(height: 8),
                        Text(
                          tr('quick_qr_login'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Tg.text),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('scan_qr_instructions'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Tg.textDim, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: qrLink,
                            version: QrVersions.auto,
                            size: 200,
                            gapless: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            setState(() => _preferPhone = true);
                            service.requestPhoneAuth();
                          },
                          child: Text(
                            tr('login_phone_btn'),
                            style: const TextStyle(fontSize: 14, color: Tg.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ] else if (phase == AuthPhase.waitPhone || (phase == AuthPhase.waitQr && _preferPhone)) ...[
                        // Вход по номеру телефона
                        const SizedBox(height: 8),
                        Text(
                          tr('login_phone_title'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Tg.text),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('code_will_arrive'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Tg.textDim, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          hint: '+7 999 123-45-67',
                          keyboardType: TextInputType.phone,
                          onSubmitted: () => _submit(AuthPhase.waitPhone),
                        ),
                        const SizedBox(height: 14),
                        _buildActionButton(
                          label: tr('continue_btn'),
                          onPressed: () => _submit(AuthPhase.waitPhone),
                        ),
                        if (!Platform.isAndroid && !Platform.isIOS) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              setState(() => _preferPhone = false);
                              service.requestQrCode();
                            },
                            child: Text(
                              tr('login_qr_btn'),
                              style: const TextStyle(fontSize: 14, color: Tg.accent, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ] else if (phase == AuthPhase.waitCode) ...[
                        // Ввод кода
                        const SizedBox(height: 8),
                        Text(
                          tr('check_tg'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Tg.text),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          codeHint ?? tr('code_hint_default'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Tg.textDim, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          hint: tr('code_input_hint'),
                          keyboardType: TextInputType.number,
                          onSubmitted: () => _submit(AuthPhase.waitCode),
                        ),
                        const SizedBox(height: 14),
                        _buildActionButton(
                          label: tr('confirm_btn'),
                          onPressed: () => _submit(AuthPhase.waitCode),
                        ),
                      ] else if (phase == AuthPhase.waitPassword) ...[
                        // 2FA Пароль
                        const SizedBox(height: 8),
                        Text(
                          tr('cloud_pwd_title'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Tg.text),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          passwordHint != null && passwordHint.isNotEmpty
                              ? tr('pwd_hint_prefix', {'hint': passwordHint})
                              : tr('pwd_hint_default'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Tg.textDim, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          hint: tr('pwd_input_hint'),
                          obscure: true,
                          onSubmitted: () => _submit(AuthPhase.waitPassword),
                        ),
                        const SizedBox(height: 14),
                        _buildActionButton(
                          label: tr('login_btn'),
                          onPressed: () => _submit(AuthPhase.waitPassword),
                        ),
                      ] else if (phase == AuthPhase.error) ...[
                        const SizedBox(height: 16),
                        const Icon(Icons.error_outline_rounded, size: 48, color: Tg.danger),
                        const SizedBox(height: 14),
                        Text(
                          tr('connection_error'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Tg.text),
                        ),
                        const SizedBox(height: 16),
                        _buildActionButton(
                          label: tr('retry_btn'),
                          onPressed: () => service.init(),
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () => AppState.demoMode.value = true,
                        child: Text(
                          tr('demo_mode_btn'),
                          style: const TextStyle(fontSize: 12.5, color: Tg.textFaint),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputField({
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    required VoidCallback onSubmitted,
  }) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      obscureText: obscure,
      autofocus: true,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Tg.text),
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        filled: true,
        fillColor: Tg.field,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14.5, color: Tg.textFaint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Tg.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _busy ? null : onPressed,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
