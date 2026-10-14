import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';

/// Аутентичное окно аудиозвонка в стиле Telegram Desktop.
class CallDialog extends StatefulWidget {
  const CallDialog({super.key, required this.chat});

  final TgChat chat;

  static void show(BuildContext context, TgChat chat) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => CallDialog(chat: chat),
    );
  }

  @override
  State<CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<CallDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _statusTimer;
  Timer? _durationTimer;
  int _seconds = 0;
  String _status = 'Соединение…';
  bool _connected = false;
  bool _muted = false;
  bool _speaker = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Имитация этапов установления соединения
    _statusTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _status = 'Идет вызов…');
      _statusTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        setState(() {
          _status = '00:00';
          _connected = true;
        });
        _durationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) return;
          setState(() {
            _seconds++;
            final m = (_seconds ~/ 60).toString().padLeft(2, '0');
            final s = (_seconds % 60).toString().padLeft(2, '0');
            _status = '$m:$s';
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  void _endCall() {
    Navigator.of(context).pop();
    final dur = _seconds > 0 ? _status : 'Звонок отменён';
    TgToast.show(
      context,
      'Звонок завершён ($dur)',
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
        width: 320,
        height: 430,
        decoration: BoxDecoration(
          color: const Color(0xFF1B232E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
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
                        _connected ? 'Сквозное шифрование' : 'Защищённый звонок',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Tg.textFaint,
                        ),
                      ),
                    ],
                  ),
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
                        color: const Color(0xFF8774E1).withValues(alpha: 0.3 * (1 - _pulseController.value)),
                        width: 4,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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
            const Spacer(),
            // Кнопки управления звонком
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
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
                    tooltip: _muted ? 'Включить микрофон' : 'Выключить микрофон',
                  ),
                  // End Call
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x66E53935),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: 28,
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
                    tooltip: 'Динамик',
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
