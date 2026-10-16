import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';
import '../../ai_copilot/models/contact_dossier.dart';
import '../../ai_copilot/services/smart_reply_engine.dart';
import '../../ai_copilot/widgets/smart_replies_bar.dart';
import 'emoji_picker_popup.dart';

/// Нижняя панель ввода текста, голосовых заметок, прикрепления файлов, Smart Replies и inline AI-запросов (@ai / /ask).
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.chat,
    required this.enabled,
    this.realMode = false,
  });

  final TgChat chat;
  final bool enabled;
  final bool realMode;

  @override
  State<ChatInputBar> createState() => ChatInputBarState();
}

class ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final List<String> _stagedFiles = [];
  final _audioRecorder = AudioRecorder();
  bool _isRecordingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _voicePath;
  bool _showEmoji = false;
  bool _showSmartReplies = false;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Добавление перетянутых или выбранных файлов в очередь отправки
  void addStagedFiles(List<String> paths) {
    final valid = paths.where((p) => p.isNotEmpty && File(p).existsSync()).toList();
    if (valid.isNotEmpty) {
      setState(() {
        _stagedFiles.addAll(valid);
      });
      TgToast.show(
        context,
        tr('attached_files_toast', {'count': valid.length.toString()}),
        icon: Icons.attach_file_rounded,
      );
    }
  }

  void _toggleVoice() {
    if (_isRecordingVoice) {
      _stopVoice(send: true);
    } else {
      _startVoice();
    }
  }

  Future<void> _startVoice() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          TgToast.show(
            context,
            tr('no_mic_permission'),
            icon: Icons.mic_off_rounded,
          );
        }
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
        path: path,
      );
      setState(() {
        _isRecordingVoice = true;
        _recordSeconds = 0;
        _voicePath = path;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (mounted) {
        TgToast.show(
          context,
          tr('recording_error', {'error': e.toString()}),
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _stopVoice({required bool send}) async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    final finalPath = path ?? _voicePath;
    if (send && finalPath != null && _recordSeconds > 0) {
      final id = int.tryParse(widget.chat.id);
      if (id != null) {
        TdlibService.instance.sendVoiceNote(id, finalPath, _recordSeconds);
      }
    }
    setState(() {
      _isRecordingVoice = false;
      _recordSeconds = 0;
      _voicePath = null;
    });
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleInlineAiQuery(String query, {required String originalText}) async {
    final isRu = I18n.instance.isRu;
    setState(() {
      _controller.text = isRu ? '🧠 Генерация ответа AI...' : '🧠 Generating AI reply...';
    });
    final statusMsg = isRu
        ? '🧠 Ответ AI на "$query"...'
        : '🧠 AI reply for "$query"...';
    AppState.aiProcessingStatus.value = statusMsg;

    try {
      final dossier = ContactDossierStore.instance.getDossier(widget.chat.id).value;
      final realMsgs = widget.realMode
          ? (TdlibService.instance.messagesOf(widget.chat.id).value.messages.isNotEmpty
              ? TdlibService.instance.messagesOf(widget.chat.id).value.messages
              : widget.chat.messages)
          : widget.chat.messages;

      final reply = await SmartReplyEngine.generateInstructionReplyAsync(
        chatTitle: widget.chat.title,
        chatId: widget.chat.id,
        chatSubtitle: widget.chat.headerSubtitle,
        messages: realMsgs,
        instruction: query,
        dossier: dossier,
      );

      if (mounted) {
        setState(() {
          _controller.text = reply;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: reply.length),
          );
        });
        TgToast.show(
          context,
          isRu ? '💡 Ответ AI подготовлен к отправке' : '💡 AI reply ready to send',
          icon: Icons.auto_awesome,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _controller.text = originalText;
        });
        TgToast.show(
          context,
          isRu ? '⚠️ Ошибка запроса к AI: $e' : '⚠️ AI request error: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      AppState.aiProcessingStatus.value = null;
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty && _stagedFiles.isEmpty) return;
    if (!widget.enabled) return;

    if (AppState.aiProcessingStatus.value != null) {
      TgToast.show(
        context,
        I18n.instance.isRu
            ? '⏳ Пожалуйста, дождитесь завершения AI запроса'
            : '⏳ Please wait for AI operation to complete',
        icon: Icons.hourglass_top_rounded,
      );
      return;
    }

    if (text.startsWith('/ai ') || text.startsWith('@ai ') || text.startsWith('/ask ')) {
      final query = text.replaceFirst(RegExp(r'^(/ai|@ai|/ask)\s+'), '').trim();
      if (query.isNotEmpty) {
        _handleInlineAiQuery(query, originalText: text);
        return;
      }
    }

    final id = int.tryParse(widget.chat.id);
    if (id == null) return;

    // Множественная отправка файлов с подписью
    if (_stagedFiles.isNotEmpty) {
      final total = _stagedFiles.length;
      for (int i = 0; i < total; i++) {
        final filePath = _stagedFiles[i];
        final caption = (i == 0) ? text : '';
        TdlibService.instance.sendFile(id, filePath, caption);
      }
      setState(() {
        _stagedFiles.clear();
      });
      _controller.clear();
      TgToast.show(
        context,
        tr('sent_files_toast', {'count': total.toString()}),
        icon: Icons.done_all_rounded,
      );
      return;
    }

    final replyMsg = AppState.replyingTo.value;
    TdlibService.instance.sendMessage(
      id,
      text,
      replyToMessageId: replyMsg?.id,
    );
    AppState.replyingTo.value = null;
    _controller.clear();
    setState(() => _showEmoji = false);
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles();
      if (result.isNotEmpty) {
        final valid = result.map((f) => f.path).whereType<String>().where((p) => File(p).existsSync()).toList();
        if (valid.isNotEmpty) {
          setState(() {
            _stagedFiles.addAll(valid);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        TgToast.show(
          context,
          tr('file_pick_error', {'error': e.toString()}),
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  void _onEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + emoji.length),
      );
    } else {
      _controller.text += emoji;
    }
    setState(() => _showEmoji = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_showEmoji)
          Padding(
            padding: const EdgeInsets.only(right: 18, bottom: 6),
            child: EmojiPickerPopup(
              onEmojiSelected: _onEmoji,
              onClose: () => setState(() => _showEmoji = false),
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
            color: Tg.sidebar,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Tg.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_stagedFiles.isNotEmpty) _buildStagedFilesBar(),
              ValueListenableBuilder<TgMessage?>(
                valueListenable: AppState.replyingTo,
                builder: (context, replyMsg, _) {
                  if (replyMsg == null) return const SizedBox.shrink();
                  final hasThumb = replyMsg.thumbnailPath.isNotEmpty &&
                      File(replyMsg.thumbnailPath).existsSync();

                  return Container(
                    color: Tg.sidebar.withValues(alpha: 0.95),
                    padding: const EdgeInsets.fromLTRB(14, 6, 12, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.reply_rounded, color: Tg.accent, size: 20),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Tg.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasThumb) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              File(replyMsg.thumbnailPath),
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr('reply_to_message'),
                                style: const TextStyle(
                                  color: Tg.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                replyMsg.text.isNotEmpty
                                    ? replyMsg.text
                                    : (replyMsg.kind == MessageKind.video
                                        ? (replyMsg.fileName.isNotEmpty ? replyMsg.fileName : tr('media_video'))
                                        : (replyMsg.kind == MessageKind.image
                                            ? tr('media_photo')
                                            : (replyMsg.kind == MessageKind.voice
                                                ? tr('media_voice')
                                                : (replyMsg.fileName.isNotEmpty ? replyMsg.fileName : tr('media_file'))))),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Tg.textDim,
                                  fontSize: 11.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Tg.textDim),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          splashRadius: 14,
                          onPressed: () => AppState.replyingTo.value = null,
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_showSmartReplies)
                SmartRepliesBar(
                  chat: widget.chat,
                  messages: widget.realMode
                      ? (TdlibService.instance.messagesOf(widget.chat.id).value.messages.isNotEmpty
                          ? TdlibService.instance.messagesOf(widget.chat.id).value.messages
                          : widget.chat.messages)
                      : widget.chat.messages,
                  onSelected: (text) {
                    _controller.text = text;
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: text.length),
                    );
                    setState(() => _showSmartReplies = false);
                  },
                  onClose: () => setState(() => _showSmartReplies = false),
                ),
              ValueListenableBuilder<String?>(
                valueListenable: AppState.aiProcessingStatus,
                builder: (context, status, _) {
                  if (status == null || _showSmartReplies) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Tg.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Tg.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Tg.accent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Tg.accent,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: _isRecordingVoice
                    ? _buildVoiceRecordingBar()
                    : _buildStandardInputBar(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStagedFilesBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Tg.field.withValues(alpha: 0.5),
        border: const Border(bottom: BorderSide(color: Tg.hairline)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _stagedFiles.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _stagedFiles.length) {
            return Center(
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Tg.accent, size: 28),
                tooltip: tr('add_more_files'),
                onPressed: _pickAttachment,
              ),
            );
          }
          final path = _stagedFiles[index];
          final fileName = path.split(Platform.pathSeparator).last;
          final isImage = path.toLowerCase().endsWith('.png') ||
              path.toLowerCase().endsWith('.jpg') ||
              path.toLowerCase().endsWith('.jpeg') ||
              path.toLowerCase().endsWith('.webp');

          return Container(
            width: 140,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Tg.sidebar,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Tg.hairline),
            ),
            child: Row(
              children: [
                if (isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(path),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Tg.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.insert_drive_file_rounded, color: Tg.accent, size: 22),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Tg.text, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getFileSize(path),
                        style: const TextStyle(fontSize: 10.5, color: Tg.textDim),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: Tg.textDim),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  splashRadius: 12,
                  onPressed: () {
                    setState(() {
                      _stagedFiles.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getFileSize(String path) {
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  Widget _buildVoiceRecordingBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Tg.field,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Tg.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDuration(_recordSeconds),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Tg.text,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              tr('recording_microphone'),
              style: const TextStyle(fontSize: 13.5, color: Tg.textDim),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Tg.textFaint),
            onPressed: () => _stopVoice(send: false),
            tooltip: tr('cancel'),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _stopVoice(send: true),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Tg.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardInputBar() {
    return Row(
      children: [
        CircleIconButton(
          icon: Icons.attach_file_rounded,
          iconSize: 22,
          color: _stagedFiles.isNotEmpty ? Tg.accent : Tg.textFaint,
          onTap: _pickAttachment,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Tg.field,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                return Focus(
                  onKeyEvent: (node, event) {
                    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                                    event.logicalKey == LogicalKeyboardKey.numpadEnter;
                    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
                                        HardwareKeyboard.instance.isMetaPressed;
                    if (isEnter && isCtrlOrCmd) {
                      if (event is KeyDownEvent) {
                        _send();
                      }
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14.5, color: Tg.text),
                    cursorWidth: 1.5,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _stagedFiles.isNotEmpty
                          ? tr('caption_hint')
                          : tr('write_message'),
                      hintStyle: const TextStyle(fontSize: 14.5, color: Tg.textFaint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixIcon: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _showEmoji = !_showEmoji),
                        child: Icon(
                          _showEmoji
                              ? Icons.keyboard_rounded
                              : Icons.sentiment_satisfied_alt_rounded,
                          size: 21,
                          color: _showEmoji ? Tg.accent : Tg.textFaint,
                        ),
                      ),
                      suffixIconConstraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: tr('ai_smart_reply_tooltip'),
          child: CircleIconButton(
            icon: Icons.auto_awesome,
            iconSize: 20,
            color: _showSmartReplies ? Tg.accent : Tg.textDim,
            onTap: () => setState(() => _showSmartReplies = !_showSmartReplies),
          ),
        ),
        const SizedBox(width: 4),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty || _stagedFiles.isNotEmpty;
            return ValueListenableBuilder<String?>(
              valueListenable: AppState.aiProcessingStatus,
              builder: (context, aiStatus, _) {
                final isAiActive = aiStatus != null;
                return GestureDetector(
                  onTap: isAiActive
                      ? () {
                          TgToast.show(
                            context,
                            I18n.instance.isRu
                                ? '⏳ Пожалуйста, дождитесь завершения AI запроса'
                                : '⏳ Please wait for AI operation to complete',
                            icon: Icons.hourglass_top_rounded,
                          );
                        }
                      : (hasText ? _send : _toggleVoice),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: isAiActive ? null : Tg.accentGradient,
                      color: isAiActive ? Tg.accent.withValues(alpha: 0.5) : null,
                      shape: BoxShape.circle,
                    ),
                    child: isAiActive
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        : Icon(
                            hasText ? Icons.send_rounded : Icons.mic_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
