import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';
import 'message_bubble.dart';

/// Лента сообщений чата с поддержкой обратного скролла, пагинации, поиска и Drag-and-Drop загрузки файлов.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.chat,
    required this.realMode,
    required this.onFilesDropped,
  });

  final TgChat chat;
  final bool realMode;
  final void Function(List<String> files) onFilesDropped;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _controller = ScrollController();
  bool _isDragging = false;
  DateTime? _lastScrollLoadTime;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    if (widget.realMode) {
      TdlibService.instance.requestHistory(widget.chat.id);
    }
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
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
                    strokeWidth: 2.5,
                    color: Tg.accent,
                  ),
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
                        strokeWidth: 2.5,
                        color: Tg.accent,
                      ),
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
