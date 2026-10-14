import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/tdlib/tdlib_service.dart';
import '../features/auth/login_screen.dart';
import '../features/chat/chat_screen.dart';
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
                SizedBox(width: width, child: const ChatListScreen()),
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
            child: Image.asset(
              'assets/images/chat_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
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
