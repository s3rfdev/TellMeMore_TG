import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../data/models/tg_account.dart';
import '../../data/tdlib/tdlib_service.dart';
import '../../state/app_state.dart';
import 'widgets/chat_header.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_list.dart';

/// Правая часть: координатор экрана чата (шапка чата, лента сообщений, поле ввода).
/// Обеспечивает реактивное переключение чатов, аккаунтов и связку drag-and-drop с полем ввода.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.showBack = false, this.onBack});

  final bool showBack;
  final VoidCallback? onBack;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ChatInputBarState> _inputBarKey = GlobalKey<ChatInputBarState>();

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
              ChatHeader(
                chat: chat,
                showBack: widget.showBack,
                onBack: widget.onBack,
              ),
              Expanded(
                child: ChatMessageList(
                  key: ValueKey(chat.id),
                  chat: chat,
                  realMode: useReal,
                  onFilesDropped: (files) =>
                      _inputBarKey.currentState?.addStagedFiles(files),
                ),
              ),
              ChatInputBar(
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
