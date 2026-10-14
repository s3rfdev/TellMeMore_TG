import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../data/models/tg_chat.dart';

/// Голосовое сообщение в стиле Telegram Desktop:
/// Круглая кнопка Play/Pause, полоса волны звука, длительность и время.
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

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _duration = Duration(seconds: widget.message.duration > 0 ? widget.message.duration : 0);

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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final path = widget.message.mediaPath;
    if (path.isEmpty || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аудиофайл еще загружается или недоступен локально.'),
          duration: Duration(seconds: 2),
        ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause Circle Button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.outgoing ? const Color(0xFF8774E1) : Tg.accent,
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
                                : const Color(0xFF8774E1).withValues(alpha: 0.5)),
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
        ],
      ),
    );
  }
}
