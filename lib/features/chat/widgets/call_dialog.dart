import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/services/call_sound_service.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';

/// Аутентичное окно аудиозвонка в стиле Telegram Desktop с поддержкой сигнализации TDLib.
class CallDialog extends StatefulWidget {
  const CallDialog({super.key, required this.chat, this.initialCall});

  final TgChat chat;
  final TgCallInfo? initialCall;

  static void show(BuildContext context, TgChat chat, {TgCallInfo? initialCall}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => CallDialog(chat: chat, initialCall: initialCall),
    );
  }

  @override
  State<CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<CallDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _durationTimer;
  Timer? _autoCloseTimer;
  int _seconds = 0;
  String _status = tr('call_connecting');
  bool _connected = false;
  bool _muted = false;
  bool _speaker = true;
  List<String> _emojis = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    AppState.activeCall.addListener(_onCallUpdate);
    final current = widget.initialCall ?? AppState.activeCall.value;
    if (current != null) {
      _updateFromCallInfo(current);
    } else {
      final targetUserId = widget.chat.userId ?? int.tryParse(widget.chat.id) ?? 0;
      if (targetUserId > 0) {
        TdlibService.instance.createCall(targetUserId);
      }
    }
  }

  void _onCallUpdate() {
    final call = AppState.activeCall.value;
    if (!mounted || call == null) return;
    setState(() => _updateFromCallInfo(call));
  }

  void _updateFromCallInfo(TgCallInfo call) {
    _emojis = call.emojis;
    switch (call.state) {
      case TgCallState.pending:
        _status = tr('call_connecting');
        _connected = false;
      case TgCallState.ringing:
        _status = tr('call_ringing');
        _connected = false;
        if (call.isOutgoing) {
          CallSoundService.startOutgoingRingback();
        }
      case TgCallState.exchangingKeys:
        _status = tr('call_key_exchange');
        _connected = false;
      case TgCallState.ready:
        CallSoundService.stop();
        if (!_connected) {
          _connected = true;
          _status = '00:00';
          _startDurationTimer();
        }
      case TgCallState.hangingUp:
        _status = tr('call_ending');
      case TgCallState.discarded:
        CallSoundService.stop();
        _status = call.discardReason.isNotEmpty ? call.discardReason : tr('call_ended');
        _durationTimer?.cancel();
        _autoCloseTimer?.cancel();
        _autoCloseTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
        });
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _seconds++;
        final m = (_seconds ~/ 60).toString().padLeft(2, '0');
        final s = (_seconds % 60).toString().padLeft(2, '0');
        _status = '$m:$s';
      });
    });
  }

  @override
  void dispose() {
    CallSoundService.stop();
    AppState.activeCall.removeListener(_onCallUpdate);
    _pulseController.dispose();
    _durationTimer?.cancel();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _endCall() {
    CallSoundService.stop();
    final call = AppState.activeCall.value;
    if (call != null) {
      TdlibService.instance.discardCall(call.callId, duration: _seconds);
    }
    if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
    final dur = _seconds > 0 ? _status : tr('call_cancelled');
    TgToast.show(
      context,
      tr('call_finished_dur', {'dur': dur}),
      icon: Icons.phone_callback_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 330,
        height: 460,
        decoration: BoxDecoration(
          color: Tg.sidebar,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Tg.border),
        ),
        child: Column(
          children: [
            // Верхняя плашка
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _connected ? const Color(0xFF43D39E) : Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _connected ? tr('call_e2e_encrypted') : tr('call_secure_call'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Tg.textFaint,
                        ),
                      ),
                    ],
                  ),
                  if (_emojis.isNotEmpty)
                    Tooltip(
                      message: tr('call_encryption_key_match'),
                      child: Text(
                        _emojis.join(' '),
                        style: const TextStyle(fontSize: 14),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Tg.textDim),
                      onPressed: _endCall,
                      splashRadius: 16,
                    ),
                ],
              ),
            ),
            const Spacer(),
            // Пульсирующий аватар
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.08);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Tg.accent.withValues(alpha: 0.35 * (1 - _pulseController.value)),
                        width: 3,
                      ),
                    ),
                    child: TgAvatar(
                      emoji: widget.chat.avatarEmoji,
                      color: Color(widget.chat.avatarColor),
                      imagePath: widget.chat.avatarPath,
                      size: 96,
                      fontSize: 34,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            // Имя собеседника
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.chat.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Статус / время
            Text(
              _status,
              style: TextStyle(
                fontSize: 13.5,
                color: _connected ? const Color(0xFF43D39E) : Tg.textDim,
                fontWeight: _connected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            // Информационный бейдж о сигнализации
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cell_tower_rounded, size: 13, color: Tg.textFaint),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tr('call_tdlib_signaling'),
                      style: const TextStyle(fontSize: 10.5, color: Tg.textFaint),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Кнопки управления звонком
            Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _callActionBtn(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    active: _muted,
                    activeColor: Colors.white.withValues(alpha: 0.25),
                    color: Colors.white.withValues(alpha: 0.1),
                    onTap: () => setState(() => _muted = !_muted),
                    tooltip: _muted ? tr('call_unmute_mic') : tr('call_mute_mic'),
                  ),
                  // End Call
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Tg.danger,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  // Speaker
                  _callActionBtn(
                    icon: _speaker ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    active: !_speaker,
                    activeColor: Colors.white.withValues(alpha: 0.25),
                    color: Colors.white.withValues(alpha: 0.1),
                    onTap: () => setState(() => _speaker = !_speaker),
                    tooltip: tr('call_speaker'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callActionBtn({
    required IconData icon,
    required bool active,
    required Color color,
    required Color activeColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: active ? activeColor : color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: active ? Colors.white : Tg.textDim,
            size: 22,
          ),
        ),
      ),
    );
  }
}
