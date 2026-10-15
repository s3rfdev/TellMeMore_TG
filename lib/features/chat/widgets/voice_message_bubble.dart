import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../ai_copilot/services/voice_transcription_service.dart';

/// Голосовое сообщение в стиле Telegram Desktop:
/// Круглая кнопка Play/Pause, полоса волны звука, длительность, кнопка STT и текст расшифровки.
class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.outgoing,
  });

  final TgMessage message;
  final bool outgoing;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _transcription;
  bool _isTranscribing = false;
  bool _showTranscription = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _duration = Duration(seconds: widget.message.duration > 0 ? widget.message.duration : 0);

    // Проверяем наличие закэшированной транскрипции
    final cached = VoiceTranscriptionService.instance.getCachedTranscription(widget.message.id) ??
        VoiceTranscriptionService.instance.getCachedTranscription(widget.message.mediaPath);
    if (cached != null && cached.isNotEmpty && !cached.startsWith('[')) {
      _transcription = cached;
      _showTranscription = true;
    }

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted && dur > Duration.zero) setState(() => _duration = dur);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _handleTranscribe() async {
    if (_showTranscription && _transcription != null) {
      setState(() => _showTranscription = false);
      return;
    }
    if (_transcription != null && _transcription!.isNotEmpty && !_transcription!.startsWith('[')) {
      setState(() => _showTranscription = true);
      return;
    }

    final path = widget.message.mediaPath;
    if (path.isEmpty || !File(path).existsSync()) {
      TgToast.show(
        context,
        I18n.instance.isRu ? 'Файл голосового сообщения ещё загружается...' : 'Voice file is downloading...',
        icon: Icons.hourglass_top_rounded,
      );
      return;
    }

    setState(() => _isTranscribing = true);
    try {
      final text = await VoiceTranscriptionService.instance.transcribeVoiceFile(
        filePath: path,
        messageId: widget.message.id,
        durationSeconds: widget.message.duration,
      );
      if (mounted) {
        if (text.isNotEmpty && !text.startsWith('[')) {
          setState(() {
            _transcription = text;
            _showTranscription = true;
          });
        } else {
          TgToast.show(
            context,
            I18n.instance.isRu ? 'Не удалось расшифровать запись' : 'Failed to transcribe voice note',
            icon: Icons.mic_off_rounded,
          );
        }
      }
    } catch (e) {
      if (mounted) TgToast.show(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final path = widget.message.mediaPath;
    if (path.isEmpty || !File(path).existsSync()) {
      TgToast.show(
        context,
        tr('audio_downloading_or_unavailable'),
        icon: Icons.hourglass_top_rounded,
      );
      return;
    }

    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(path));
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final totalSec = _duration.inSeconds > 0 ? _duration.inSeconds : widget.message.duration;
    final currentSec = _position.inSeconds;
    final displaySec = isPlaying ? currentSec : totalSec;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play / Pause Circle Button
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.outgoing ? Tg.accentDark : Tg.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Waveform & Timers
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Waveform representation
                  SizedBox(
                    width: 170,
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(24, (i) {
                        final progress = totalSec > 0 ? currentSec / totalSec : 0.0;
                        final barFraction = i / 24.0;
                        final active = isPlaying && barFraction <= progress;

                        // Wave heights pattern
                        const heights = [
                          6.0, 10.0, 16.0, 12.0, 18.0, 14.0, 8.0, 15.0,
                          20.0, 16.0, 10.0, 14.0, 18.0, 12.0, 15.0, 9.0,
                          13.0, 17.0, 11.0, 14.0, 16.0, 10.0, 7.0, 5.0,
                        ];
                        final h = heights[i % heights.length];

                        return Container(
                          width: 3.5,
                          height: h,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : (widget.outgoing
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : Tg.accent.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Duration & timestamp row
                  SizedBox(
                    width: 170,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(displaySec),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.outgoing ? Tg.timeOut : Tg.textDim,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.message.time,
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.outgoing ? Tg.timeOut : Tg.service,
                              ),
                            ),
                            if (widget.outgoing) ...[
                              const SizedBox(width: 3),
                              Icon(
                                widget.message.read ? Icons.done_all : Icons.done,
                                size: 14,
                                color: Tg.ticks,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Transcribe Button
              GestureDetector(
                onTap: _handleTranscribe,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _showTranscription
                        ? (widget.outgoing ? Colors.white.withValues(alpha: 0.25) : Tg.accent.withValues(alpha: 0.18))
                        : (widget.outgoing ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _isTranscribing
                      ? Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.outgoing ? Colors.white : Tg.accent,
                            ),
                          ),
                        )
                      : Icon(
                          _showTranscription ? Icons.subtitles_rounded : Icons.subtitles_outlined,
                          size: 16,
                          color: widget.outgoing
                              ? (_showTranscription ? Colors.white : Colors.white.withValues(alpha: 0.7))
                              : (_showTranscription ? Tg.accent : Tg.textDim),
                        ),
                ),
              ),
            ],
          ),
          if (_showTranscription && _transcription != null && _transcription!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.outgoing
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _transcription!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: widget.outgoing ? Colors.white : Tg.text,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
