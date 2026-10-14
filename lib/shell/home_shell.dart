import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/widgets/tg_avatar.dart';
import '../data/models/tg_chat.dart';
import '../data/tdlib/td_content.dart';
import '../data/tdlib/tdlib_service.dart';
import '../features/auth/login_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/widgets/call_dialog.dart';
import '../features/chat_list/chat_list_screen.dart';
import '../features/chat_list/widgets/main_drawer.dart';
import '../state/app_state.dart';

/// Каркас: слева список чатов (перетаскивается за разделитель),
/// справа окно чата. На узком экране сайдбар выезжает поверх чата.
/// Пока нет авторизации в Telegram — показываем экран входа.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _overlayOpen = true;

  static const _minSidebar = 280.0;
  static const _maxSidebar = 640.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TdlibService.instance.phase,
        AppState.demoMode,
      ]),
      builder: (context, _) {
        final loggedIn = kIsWeb ||
            AppState.demoMode.value ||
            TdlibService.instance.phase.value == AuthPhase.ready;
        if (!loggedIn) return const LoginScreen();
        return _layout();
      },
    );
  }

  Widget _layout() {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;

      final Widget mainContent;
      if (wide) {
        mainContent = ValueListenableBuilder<double>(
          valueListenable: AppState.sidebarWidth,
          builder: (context, raw, _) {
            final width = raw.clamp(_minSidebar, _maxSidebar);
            return Row(
              children: [
                SizedBox(
                  width: width,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(10, 10, 0, 10),
                    child: ChatListScreen(),
                  ),
                ),
                _DragHandle(
                  onDrag: (dx) => AppState.sidebarWidth.value =
                      (AppState.sidebarWidth.value + dx)
                          .clamp(_minSidebar, _maxSidebar),
                ),
                const Expanded(child: ChatScreen()),
              ],
            );
          },
        );
      } else {
        mainContent = Stack(
          children: [
            ChatScreen(
              showBack: true,
              onBack: () => setState(() => _overlayOpen = true),
            ),
            AnimatedSlide(
              offset: _overlayOpen ? Offset.zero : const Offset(-1, 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: (constraints.maxWidth - 48).clamp(_minSidebar, 420.0),
                child: ChatListScreen(
                  elevated: true,
                  onChatOpened: () => setState(() => _overlayOpen = false),
                ),
              ),
            ),
          ],
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F1721),
              child: Opacity(
                opacity: 0.15, // 85% прозрачность, чтобы узор не слепил и был мягким как в оригинале
                child: Image.asset(
                  'assets/images/chat_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: mainContent,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppState.drawerOpen,
            builder: (context, open, _) {
              if (!open) return const SizedBox.shrink();
              return Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => AppState.drawerOpen.value = false,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: MainDrawer(
                      onClose: () => AppState.drawerOpen.value = false,
                    ),
                  ),
                ],
              );
            },
          ),
          ValueListenableBuilder<TgCallInfo?>(
            valueListenable: AppState.incomingCall,
            builder: (context, call, _) {
              if (call == null) return const SizedBox.shrink();
              return _IncomingCallBanner(call: call);
            },
          ),
        ],
      );
    });
  }
}

class _DragHandle extends StatefulWidget {
  const _DragHandle({required this.onDrag});

  final void Function(double dx) onDrag;

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        child: SizedBox(
          width: 12,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 2.5 : 1,
              color: active
                  ? const Color(0xFF8774E1)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingCallBanner extends StatelessWidget {
  const _IncomingCallBanner({required this.call});

  final TgCallInfo call;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 18,
      right: 18,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 330,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B232E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF43D39E).withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              TgAvatar(
                emoji: TdContent.initials(call.userName),
                color: const Color(0xFF65AADD),
                size: 44,
                fontSize: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      call.userName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Входящий аудиозвонок…',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF43D39E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Отклонить (красный)
              Tooltip(
                message: 'Отклонить вызов',
                child: GestureDetector(
                  onTap: () {
                    TdlibService.instance.discardCall(call.callId);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Принять (зелёный)
              Tooltip(
                message: 'Принять звонок',
                child: GestureDetector(
                  onTap: () {
                    TdlibService.instance.acceptCall(call.callId);
                    final matchingChat = TdlibService.instance.chats.value.firstWhere(
                      (c) => c.userId == call.userId || c.id == call.userId.toString(),
                      orElse: () => TgChat(
                        id: call.userId.toString(),
                        userId: call.userId,
                        title: call.userName,
                        avatarEmoji: TdContent.initials(call.userName),
                        avatarColor: 0xFF65AADD,
                        sender: '',
                        preview: '',
                        time: '',
                        headerSubtitle: 'Звонок',
                      ),
                    );
                    CallDialog.show(context, matchingChat, initialCall: call);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFF43D39E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

