import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/theme/tg_theme.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../data/tdlib/tdlib_service.dart';
import '../../data/mock_data.dart';
import '../../state/app_state.dart';
import 'widgets/emoji_picker_popup.dart';
import 'widgets/message_bubble.dart';

/// Правая часть: шапка чата, лента сообщений, поле ввода.
/// Работает и с моками (демо), и с реальными данными TDLib.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, this.showBack = false, this.onBack});

  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppState.selectedChatId,
        TdlibService.instance.chats,
      ]),
      builder: (context, _) {
        final id = AppState.selectedChatId.value;
        final realChats = TdlibService.instance.chats.value;
        final useReal =
            !kIsWeb && !AppState.demoMode.value && realChats.isNotEmpty;

        final TgChat chat;
        if (useReal) {
          final found = realChats.where((c) => c.id == id).toList();
          chat = found.isNotEmpty ? found.first : realChats.first;
        } else {
          chat = mockChats.firstWhere(
            (c) => c.id == id,
            orElse: () => mockChats.first,
          );
        }

        return Container(
          color: Tg.chatBg,
          child: Column(
            children: [
              _Header(chat: chat, showBack: showBack, onBack: onBack),
              Expanded(
                child: _MessageList(
                  key: ValueKey(chat.id),
                  chat: chat,
                  realMode: useReal,
                ),
              ),
              _InputBar(chat: chat, enabled: useReal),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.chat, required this.showBack, this.onBack});

  final TgChat chat;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Tg.sidebar,
        border: Border(bottom: BorderSide(color: Tg.hairline)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            const SizedBox(width: 4),
            CircleIconButton(
              icon: Icons.arrow_back_ios_new,
              iconSize: 16,
              color: Tg.textDim,
              onTap: onBack,
            ),
          ],
          const SizedBox(width: 12),
          TgAvatar(
            emoji: chat.avatarEmoji,
            color: Color(chat.avatarColor),
            imagePath: chat.avatarPath,
            size: 36,
            fontSize: 15,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Tg.text,
                        ),
                      ),
                    ),
                    if (chat.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: Tg.verified),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  chat.headerSubtitle,
                  style: const TextStyle(fontSize: 11.5, color: Tg.textFaint),
                ),
              ],
            ),
          ),
          const CircleIconButton(icon: Icons.phone_outlined, iconSize: 20, color: Tg.textDim),
          const CircleIconButton(icon: Icons.search, iconSize: 20, color: Tg.textDim),
          const CircleIconButton(icon: Icons.more_horiz, iconSize: 20, color: Tg.textDim),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Лента сообщений: 20 последних при открытии, догрузка вверх при скролле.
class _MessageList extends StatefulWidget {
  const _MessageList({super.key, required this.chat, required this.realMode});

  final TgChat chat;
  final bool realMode;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    if (widget.realMode) {
      TdlibService.instance.requestHistory(widget.chat.id);
    }
  }

  @override
  void didUpdateWidget(_MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.realMode && oldWidget.chat.id != widget.chat.id) {
      TdlibService.instance.requestHistory(widget.chat.id);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.realMode) return;
    final pos = _controller.position;
    // список развёрнут (новые внизу) — «верх» это maxScrollExtent
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      TdlibService.instance.loadMore(widget.chat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.realMode) return _buildList(widget.chat.messages, false);

    return ListenableBuilder(
      listenable: Listenable.merge([
        TdlibService.instance.messagesOf(widget.chat.id),
        TdlibService.instance.loadingMore,
        TdlibService.instance.loadingHistory,
      ]),
      builder: (context, _) {
        final history = TdlibService.instance.messagesOf(widget.chat.id).value;
        final loadingMore = TdlibService.instance.loadingMore.value
            .contains(widget.chat.id);
        final initialLoading = TdlibService.instance.loadingHistory.value
            .contains(widget.chat.id);
        final isEmpty = history.messages.isEmpty;

        return _buildList(
          history.messages,
          history.hasMore && loadingMore,
          isLoadingInitial: isEmpty && initialLoading,
          isEmpty: isEmpty && !initialLoading,
        );
      },
    );
  }

  Widget _buildList(
    List<TgMessage> messages,
    bool showLoader, {
    bool isLoadingInitial = false,
    bool isEmpty = false,
  }) {
    if (isLoadingInitial) {
      return ListenableBuilder(
        listenable: TdlibService.instance.errorText,
        builder: (context, _) {
          final error = TdlibService.instance.errorText.value;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Tg.accent),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Tg.danger),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 26, color: Tg.textDim),
            ),
            const SizedBox(height: 12),
            const Text(
              'В этом чате пока нет сообщений',
              style: TextStyle(
                fontSize: 13.5,
                color: Tg.textDim,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }
    final items = messages.reversed.toList();
    return ListView.builder(
      controller: _controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: items.length + (showLoader ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(10),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Tg.accent),
              ),
            ),
          );
        }
        return MessageBubble(message: items[i], chatId: widget.chat.id);
      },
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({required this.chat, required this.enabled});

  final TgChat chat;
  final bool enabled;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _controller = TextEditingController();
  final _audioRecorder = AudioRecorder();
  bool _isRecordingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _voicePath;
  bool _showEmoji = false;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleVoice() {
    if (_isRecordingVoice) {
      _stopVoice(send: true);
    } else {
      _startVoice();
    }
  }

  Future<void> _startVoice() async {
    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Разрешение на микрофон не предоставлено')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _voicePath = path;
    try {
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _isRecordingVoice = true;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка старта записи: $e')),
        );
      }
    }
  }

  Future<void> _stopVoice({required bool send}) async {
    _recordTimer?.cancel();
    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (_) {}
    final finalPath = path ?? _voicePath;
    if (send && _recordSeconds > 0 && finalPath != null) {
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

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    final id = int.tryParse(widget.chat.id);
    if (id != null) {
      final replyMsg = AppState.replyingTo.value;
      TdlibService.instance.sendMessage(
        id,
        text,
        replyToMessageId: replyMsg?.id,
      );
      AppState.replyingTo.value = null;
    }
    _controller.clear();
    setState(() => _showEmoji = false);
  }

  Future<void> _pickAttachment() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isNotEmpty && files.first.path != null) {
        final id = int.tryParse(widget.chat.id);
        if (id != null) {
          TdlibService.instance.sendFile(id, files.first.path!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при выборе файла: $e')),
        );
      }
    }
  }

  void _onEmoji(String emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final newText = text.replaceRange(start, end, emoji);
    _controller.text = newText;
    _controller.selection =
        TextSelection.collapsed(offset: start + emoji.length);
    setState(() => _showEmoji = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showEmoji)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: EmojiPickerPopup(
                onEmojiSelected: _onEmoji,
                onClose: () => setState(() => _showEmoji = false),
              ),
            ),
          ),
        ValueListenableBuilder<TgMessage?>(
          valueListenable: AppState.replyingTo,
          builder: (context, replyMsg, _) {
            if (replyMsg == null) return const SizedBox.shrink();
            return Container(
              color: Tg.sidebar,
              padding: const EdgeInsets.fromLTRB(14, 6, 10, 4),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Tg.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Ответ',
                          style: TextStyle(
                            color: Tg.accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          replyMsg.text.isNotEmpty
                              ? replyMsg.text
                              : (replyMsg.fileName.isNotEmpty ? replyMsg.fileName : 'Медиа'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Tg.textDim,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Tg.textDim),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    splashRadius: 14,
                    onPressed: () => AppState.replyingTo.value = null,
                  ),
                ],
              ),
            );
          },
        ),
        Container(
          color: Tg.sidebar,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: _isRecordingVoice
              ? _buildVoiceRecordingBar()
              : _buildStandardInputBar(),
        ),
      ],
    );
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
          const Expanded(
            child: Text(
              'Идет запись микрофона…',
              style: TextStyle(fontSize: 13.5, color: Tg.textDim),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Tg.textFaint),
            onPressed: () => _stopVoice(send: false),
            tooltip: 'Отмена',
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
          color: Tg.textFaint,
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
                return TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(fontSize: 14.5, color: Tg.text),
                  cursorWidth: 1.5,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Сообщение…',
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
                        color: _showEmoji ? const Color(0xFF8774E1) : Tg.textFaint,
                      ),
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;
            return GestureDetector(
              onTap: hasText ? _send : _toggleVoice,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8774E1), Color(0xFF766AC8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
