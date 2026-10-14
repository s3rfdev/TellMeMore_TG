import 'package:flutter/material.dart';

import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_avatar.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../../state/app_state.dart';

/// Главное меню Telegram Desktop (выдвигается по кнопке ≡).
class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      height: double.infinity,
      color: Tg.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _userHeader(context),
          const Divider(height: 1, color: Tg.hairline),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                _menuItem(
                  icon: Icons.account_circle_outlined,
                  title: 'Мой профиль',
                  onTap: () {
                    onClose();
                    _showProfileDialog(context);
                  },
                ),
                _menuItem(
                  icon: Icons.group_outlined,
                  title: 'Создать группу',
                  onTap: () {
                    onClose();
                    _showNewChatDialog(context, isGroup: true);
                  },
                ),
                _menuItem(
                  icon: Icons.campaign_outlined,
                  title: 'Создать канал',
                  onTap: () {
                    onClose();
                    _showNewChatDialog(context, isGroup: false);
                  },
                ),
                _menuItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Контакты',
                  onTap: () {
                    onClose();
                    _showContactsDialog(context);
                  },
                ),
                _menuItem(
                  icon: Icons.phone_outlined,
                  title: 'Звонки',
                  onTap: () {
                    onClose();
                    TgToast.show(
                      context,
                      'Журнал звонков пуст',
                      icon: Icons.phone_disabled_rounded,
                    );
                  },
                ),
                _menuItem(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Избранное',
                  onTap: () {
                    onClose();
                    // Open saved messages (self chat)
                    final user = TdlibService.instance.currentUser.value;
                    if (user != null) {
                      AppState.selectedChatId.value = user.id.toString();
                    }
                  },
                ),
                _menuItem(
                  icon: Icons.settings_outlined,
                  title: 'Настройки',
                  onTap: () {
                    onClose();
                    _showSettingsDialog(context);
                  },
                ),
                const Divider(height: 12, color: Tg.hairline),
                _nightModeRow(),
              ],
            ),
          ),
          const Divider(height: 1, color: Tg.hairline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'TG Answer Desktop 1.0.0 (TDLib)',
              style: TextStyle(
                fontSize: 12,
                color: Tg.textFaint.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userHeader(BuildContext context) {
    return ValueListenableBuilder<TgUser?>(
      valueListenable: TdlibService.instance.currentUser,
      builder: (context, user, _) {
        final name = user?.fullName.isNotEmpty == true ? user!.fullName : 'Мой аккаунт';
        final phone = user?.phoneNumber.isNotEmpty == true ? user!.phoneNumber : 'Telegram подключен';
        final initial = user?.avatarEmoji ?? '👤';
        final color = user?.avatarColor ?? 0xFF766AC8;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          color: Tg.sidebar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TgAvatar(
                    emoji: initial,
                    color: Color(color),
                    size: 48,
                    fontSize: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Tg.textDim),
                    onPressed: onClose,
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Tg.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                phone,
                style: const TextStyle(fontSize: 13, color: Tg.textDim),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Icon(icon, color: Tg.textDim, size: 21),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, color: Tg.text),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      hoverColor: Colors.white.withValues(alpha: 0.05),
    );
  }

  Widget _nightModeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.nightlight_round, color: Tg.textDim, size: 21),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Ночной режим',
              style: TextStyle(fontSize: 14, color: Tg.text),
            ),
          ),
          Switch(
            value: true,
            activeTrackColor: const Color(0xFF8774E1),
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final user = TdlibService.instance.currentUser.value;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF212126),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2E2E34), width: 1),
        ),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Мой профиль',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Tg.textDim),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: TgAvatar(
                  emoji: user?.avatarEmoji ?? '👤',
                  color: Color(user?.avatarColor ?? 0xFF766AC8),
                  size: 64,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 18),
              _infoRow('Имя', user?.fullName ?? 'Пользователь'),
              _infoRow('Телефон', user?.phoneNumber ?? 'Не указан'),
              _infoRow('Username', user?.username.isNotEmpty == true ? '@${user!.username}' : '—'),
              _infoRow('Telegram ID', user?.id.toString() ?? '—'),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8774E1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  ),
                  child: const Text('Закрыть', style: TextStyle(fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF212126),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2E2E34), width: 1),
        ),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Настройки TG Answer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Tg.textDim),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Статус сессии:',
                style: TextStyle(fontSize: 12, color: Tg.textDim),
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Tg.accent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Подключено (TDLib SQLite session активна)',
                    style: TextStyle(fontSize: 13.5, color: Tg.accent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Путь базы данных:',
                style: TextStyle(fontSize: 12, color: Tg.textDim),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '~/.local/share/tg_answer/tdlib/db',
                  style: TextStyle(fontSize: 12, color: Tg.text.withValues(alpha: 0.85), fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Адаптивный интерфейс:',
                style: TextStyle(fontSize: 12, color: Tg.textDim),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ресайз колонок мышь/drag, компактный шрифт 14.5px, лайтбокс фото, кликабельные @mentions.',
                style: TextStyle(fontSize: 13, color: Tg.text),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8774E1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  ),
                  child: const Text('Готово', style: TextStyle(fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewChatDialog(BuildContext context, {required bool isGroup}) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF212126),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2E2E34), width: 1),
        ),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGroup ? 'Создать группу' : 'Создать канал',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8774E1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E2E34)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: titleController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: isGroup ? 'Название группы' : 'Название канала',
                          hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isGroup
                    ? 'Вы сможете пригласить участников сразу после создания.'
                    : 'Каналы используются для трансляции сообщений неограниченной аудитории.',
                style: const TextStyle(fontSize: 12, color: Tg.textDim),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: Tg.textDim,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Отмена', style: TextStyle(fontSize: 13.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isNotEmpty) {
                        TdlibService.instance.createGroup(title);
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8774E1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: const Text(
                      'Создать',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF212126),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2E2E34), width: 1),
        ),
        child: Container(
          width: 360,
          height: 420,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Контакты',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Tg.textDim),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ValueListenableBuilder<List<TgChat>>(
                  valueListenable: TdlibService.instance.chats,
                  builder: (context, chats, _) {
                    if (chats.isEmpty) {
                      return const Center(child: Text('Контакты загружаются…', style: TextStyle(color: Tg.textDim)));
                    }
                    return ListView.separated(
                      itemCount: chats.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: Tg.hairline),
                      itemBuilder: (ctx, i) {
                        final c = chats[i];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: TgAvatar(emoji: c.avatarEmoji, color: Color(c.avatarColor), size: 36, fontSize: 15),
                          title: Text(c.title, style: const TextStyle(color: Tg.text, fontSize: 13.5)),
                          subtitle: Text(c.headerSubtitle, style: const TextStyle(color: Tg.textDim, fontSize: 12)),
                          onTap: () {
                            Navigator.pop(ctx);
                            AppState.selectedChatId.value = c.id;
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Tg.textDim)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: Tg.text, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
