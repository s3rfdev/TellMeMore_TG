import 'dart:async';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/localization/app_locale.dart';
import '../../core/theme/tg_theme.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/tg_avatar.dart';
import '../../core/widgets/tg_toast.dart';
import '../../data/tdlib/tdlib_service.dart';
import '../../data/mock_data.dart';
import '../../data/models/tg_account.dart';
import '../../state/app_state.dart';
import '../ai_copilot/widgets/contact_dossier_sheet.dart';
import '../ai_copilot/widgets/smart_replies_bar.dart';
import 'services/chat_export_service.dart';
import 'widgets/chat_export_dialog.dart';
import 'widgets/chat_system_prompt_dialog.dart';
import 'widgets/emoji_picker_popup.dart';
import 'widgets/forward_dialog.dart';
import 'widgets/message_bubble.dart';

/// Правая часть: шапка чата, лента сообщений, поле ввода.
/// Поддерживает Drag-and-Drop файлов, мульти-прикрепление, звонки, поиск и выбор сообщений.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.showBack = false, this.onBack});

  final bool showBack;
  final VoidCallback? onBack;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<_InputBarState> _inputBarKey = GlobalKey<_InputBarState>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppState.selectedChatId,
        AppState.demoMode,
        TdlibService.instance.chats,
        AccountManager.instance.currentAccount,
      ]),
      builder: (context, _) {
        final id = AppState.selectedChatId.value;
        final currentAcc = AccountManager.instance.currentAccount.value;
        final realChats = TdlibService.instance.chats.value;
        final isPrimary = currentAcc.id == 'sergei';
        final useReal =
            !kIsWeb && !AppState.demoMode.value && realChats.isNotEmpty && isPrimary;

        final accountChats = useReal
            ? realChats
            : AccountManager.instance.getChats(currentAcc.id);

        final TgChat chat;
        if (accountChats.isNotEmpty) {
          final found = accountChats.where((c) => c.id == id).toList();
          chat = found.isNotEmpty ? found.first : accountChats.first;
        } else {
          chat = mockChats.first;
        }

        return Container(
          color: Colors.transparent,
          child: Column(
            children: [
              _Header(
                chat: chat,
                showBack: widget.showBack,
                onBack: widget.onBack,
              ),
              Expanded(
                child: _MessageList(
                  key: ValueKey(chat.id),
                  chat: chat,
                  realMode: useReal,
                  onFilesDropped: (files) =>
                      _inputBarKey.currentState?.addStagedFiles(files),
                ),
              ),
              _InputBar(
                key: _inputBarKey,
                chat: chat,
                enabled: useReal,
                realMode: useReal,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.chat,
    required this.showBack,
    this.onBack,
  });

  final TgChat chat;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppState.messageSelectionMode,
        AppState.selectedMessages,
        AppState.chatSearchActive,
      ]),
      builder: (context, _) {
        final isSelection = AppState.messageSelectionMode.value;
        final isSearch = AppState.chatSearchActive.value;

        return Container(
          height: 52,
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          decoration: BoxDecoration(
            color: Tg.sidebar,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Tg.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: isSelection
              ? _buildSelectionHeader(context)
              : isSearch
                  ? _buildSearchHeader(context)
                  : _buildNormalHeader(context),
        );
      },
    );
  }

  Widget _buildSelectionHeader(BuildContext context) {
    final count = AppState.selectedMessages.value.length;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Tg.textDim),
          onPressed: () {
            AppState.messageSelectionMode.value = false;
            AppState.selectedMessages.value = {};
          },
        ),
        const SizedBox(width: 6),
        Text(
          tr('selected_count', {'count': count.toString()}),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tg.text),
        ),
        const Spacer(),
        if (count > 0) ...[
          IconButton(
            icon: const Icon(Icons.shortcut_rounded, color: Tg.accent),
            tooltip: tr('forward'),
            onPressed: () {
              final msgIds = AppState.selectedMessages.value;
              final history = TdlibService.instance.messagesOf(chat.id).value.messages;
              final found = history.where((m) => msgIds.contains(m.id)).toList();
              if (found.isNotEmpty) {
                ForwardDialog.show(context, message: found.first, currentChatId: chat.id);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Tg.danger),
            tooltip: tr('delete'),
            onPressed: () => _confirmDeleteSelected(context),
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  void _confirmDeleteSelected(BuildContext context) {
    final count = AppState.selectedMessages.value.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212D3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('delete_messages_title'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text(tr('delete_messages_confirm', {'count': count.toString()}), style: const TextStyle(color: Tg.textDim, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final id = int.tryParse(chat.id);
              if (id != null) {
                TdlibService.instance.deleteMessages(id, AppState.selectedMessages.value.toList());
                AppState.messageSelectionMode.value = false;
                AppState.selectedMessages.value = {};
                TgToast.show(context, tr('deleted_messages_toast', {'count': count.toString()}), icon: Icons.delete_outline_rounded);
              }
            },
            child: Text(tr('delete'), style: const TextStyle(color: Tg.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 14),
        const Icon(Icons.search_rounded, size: 20, color: Tg.textDim),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            autofocus: true,
            onChanged: (v) => AppState.chatSearchQuery.value = v,
            style: const TextStyle(fontSize: 14, color: Tg.text),
            decoration: InputDecoration(
              hintText: tr('search_messages_hint'),
              hintStyle: const TextStyle(fontSize: 14, color: Tg.textFaint),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20, color: Tg.textDim),
          onPressed: () {
            AppState.chatSearchActive.value = false;
            AppState.chatSearchQuery.value = '';
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildNormalHeader(BuildContext context) {
    return Row(
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
        Tooltip(
          message: I18n.instance.isRu ? 'AI-ассистент: досье и промпт' : 'AI Assistant: Dossier & Prompt',
          child: CircleIconButton(
            icon: Icons.psychology_rounded,
            iconSize: 20,
            color: Tg.accent,
            onTap: () => ContactDossierDialog.show(context, chat),
          ),
        ),
        CircleIconButton(
          icon: Icons.search,
          iconSize: 20,
          color: Tg.textDim,
          onTap: () => AppState.chatSearchActive.value = true,
        ),
        SizedBox(
          width: 36,
          height: 36,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: Tg.textDim),
            padding: EdgeInsets.zero,
            color: Tg.card,
            elevation: 0,
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Tg.border),
            ),
          onSelected: (val) {
            if (val == 'system_prompt') {
              ChatSystemPromptDialog.show(context, chat);
            } else if (val == 'select') {
              AppState.messageSelectionMode.value = true;
              AppState.selectedMessages.value = {};
            } else if (val == 'export_advisor') {
              ChatExportDialog.show(
                context,
                chat,
                initialType: ExportContentType.advisorProfile,
              );
            } else if (val == 'export_chat') {
              ChatExportDialog.show(
                context,
                chat,
                initialType: ExportContentType.chatHistory,
              );
            } else if (val == 'clear') {
              _confirmClearHistory(context);
            } else if (val == 'delete') {
              _confirmDeleteChat(context);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'system_prompt',
              child: Row(
                children: [
                  const Icon(Icons.psychology_rounded, size: 18, color: Tg.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      I18n.instance.isRu ? 'Системный промпт AI' : 'AI System Prompt',
                      style: const TextStyle(color: Tg.text, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'select',
              child: Row(
                children: [
                  const Icon(Icons.checklist_rounded, size: 18, color: Tg.textDim),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tr('select_messages'), style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'export_advisor',
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 18, color: Tg.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tr('export_profile_advisor'), style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'export_chat',
              child: Row(
                children: [
                  const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF4FAAFF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tr('export_chat_txt'), style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services_rounded, size: 18, color: Tg.textDim),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tr('clear_history'), style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 18, color: Tg.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tr('delete_chat'), style: const TextStyle(color: Tg.danger, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 6),
      ],
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212D3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('clear_history'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text(tr('clear_history_confirm', {'title': chat.title}), style: const TextStyle(color: Tg.textDim, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final id = int.tryParse(chat.id);
              if (id != null) {
                TdlibService.instance.clearHistory(id);
                TgToast.show(context, tr('history_cleared_toast'), icon: Icons.cleaning_services_rounded);
              }
            },
            child: Text(tr('clear'), style: const TextStyle(color: Tg.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212D3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('delete_chat'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text(tr('delete_chat_confirm', {'title': chat.title}), style: const TextStyle(color: Tg.textDim, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final id = int.tryParse(chat.id);
              if (id != null) {
                TdlibService.instance.deleteChat(id);
                AppState.selectedChatId.value = '';
                TgToast.show(context, tr('chat_deleted_toast'), icon: Icons.delete_outline_rounded);
              }
            },
            child: Text(tr('delete'), style: const TextStyle(color: Tg.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Лента сообщений: Drag-and-Drop прием файлов, 20 последних при открытии, догрузка вверх при скролле.
class _MessageList extends StatefulWidget {
  const _MessageList({
    super.key,
    required this.chat,
    required this.realMode,
    required this.onFilesDropped,
  });

  final TgChat chat;
  final bool realMode;
  final void Function(List<String> files) onFilesDropped;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _controller = ScrollController();
  bool _isDragging = false;

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

  DateTime? _lastScrollLoadTime;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.realMode) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      final now = DateTime.now();
      if (_lastScrollLoadTime != null &&
          now.difference(_lastScrollLoadTime!).inMilliseconds < 500) {
        return;
      }
      _lastScrollLoadTime = now;
      TdlibService.instance.loadMore(widget.chat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppState.messageSelectionMode,
        AppState.selectedMessages,
        AppState.chatSearchQuery,
      ]),
      builder: (context, _) {
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
            Text(
              tr('empty_chat_placeholder'),
              style: const TextStyle(
                fontSize: 13.5,
                color: Tg.textDim,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    // Фильтрация поиска внутри чата
    final query = AppState.chatSearchQuery.value.trim().toLowerCase();
    final filtered = query.isEmpty
        ? messages
        : messages.where((m) =>
            m.text.toLowerCase().contains(query) ||
            m.fileName.toLowerCase().contains(query)).toList();

    if (query.isNotEmpty && filtered.isEmpty) {
      return Center(
        child: Text(
          tr('nothing_found_query', {'query': query}),
          style: const TextStyle(color: Tg.textDim, fontSize: 14),
        ),
      );
    }

    final items = filtered.reversed.toList();
    final isSelection = AppState.messageSelectionMode.value;
    final selectedIds = AppState.selectedMessages.value;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        final paths = details.files
            .map((f) => f.path)
            .where((p) => p.isNotEmpty && File(p).existsSync())
            .toList();
        if (paths.isNotEmpty) {
          widget.onFilesDropped(paths);
        }
      },
      child: Stack(
        children: [
          ListView.builder(
            controller: _controller,
            reverse: true,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
              final msg = items[i];
              return MessageBubble(
                message: msg,
                chatId: widget.chat.id,
                selectionMode: isSelection,
                isSelected: selectedIds.contains(msg.id),
                onSelectToggle: () {
                  final s = Set<int>.from(AppState.selectedMessages.value);
                  if (s.contains(msg.id)) {
                    s.remove(msg.id);
                  } else {
                    s.add(msg.id);
                  }
                  AppState.selectedMessages.value = s;
                },
              );
            },
          ),
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: Tg.sidebar,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Tg.accent, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.file_upload_outlined, size: 52, color: Tg.accent),
                        const SizedBox(height: 12),
                        Text(
                          tr('drag_files_drop'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    super.key,
    required this.chat,
    required this.enabled,
    this.realMode = false,
  });

  final TgChat chat;
  final bool enabled;
  final bool realMode;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
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

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty && _stagedFiles.isEmpty) return;
    if (!widget.enabled) return;
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
            return GestureDetector(
              onTap: hasText ? _send : _toggleVoice,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  gradient: Tg.accentGradient,
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
