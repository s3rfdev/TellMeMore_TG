import 'package:flutter/material.dart';

import '../../core/localization/app_locale.dart';
import '../../core/services/call_sound_service.dart';
import '../../core/theme/tg_theme.dart';
import '../../core/widgets/tg_toast.dart';

class NotificationsSettingsDialog extends StatefulWidget {
  const NotificationsSettingsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const NotificationsSettingsDialog(),
    );
  }

  @override
  State<NotificationsSettingsDialog> createState() => _NotificationsSettingsDialogState();
}

class _NotificationsSettingsDialogState extends State<NotificationsSettingsDialog> {
  bool _allAccounts = true;
  bool _privateChats = true;
  bool _groups = true;
  bool _channels = true;
  bool _stories = false;
  bool _reactions = true;

  String _vibrate = 'Default';
  final String _ringtone = 'Telegram.ogg (Default)';

  bool _badgeIcon = true;
  bool _includeMuted = false;
  bool _countUnread = true;

  bool _contactJoined = true;
  bool _pinnedMessages = true;

  bool _keepAlive = true;
  bool _bgConnection = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 440,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: Tg.sidebar,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Tg.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _buildAllAccountsCard(),
                    const SizedBox(height: 14),
                    _buildChatsCard(),
                    const SizedBox(height: 14),
                    _buildCallsCard(context),
                    const SizedBox(height: 14),
                    _buildBadgeCard(),
                    const SizedBox(height: 14),
                    _buildEventsCard(),
                    const SizedBox(height: 14),
                    _buildOtherCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Tg.sidebar,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Tg.textDim, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('notifications_sounds'),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: Tg.fontMedium,
                color: Tg.text,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Tg.textDim, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({String? header, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 6),
            child: Text(
              header,
              style: const TextStyle(fontSize: 12, fontWeight: Tg.fontMedium, color: Tg.accent),
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2B38),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildAllAccountsCard() {
    return _buildCard(
      header: tr('show_notifications_from'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: _allAccounts,
            activeThumbColor: const Color(0xFF55A5EB),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('all_accounts'), style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500)),
            onChanged: (v) => setState(() => _allAccounts = v),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr('turn_off_notifications_hint'),
              style: const TextStyle(fontSize: 11.5, color: Tg.textDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsCard() {
    return _buildCard(
      header: tr('notifications_for_chats'),
      child: Column(
        children: [
          _switchRow(
            icon: Icons.person_outline_rounded,
            title: tr('private_chats'),
            subtitle: tr('tap_to_change'),
            value: _privateChats,
            onChanged: (v) => setState(() => _privateChats = v),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _switchRow(
            icon: Icons.group_outlined,
            title: tr('groups'),
            subtitle: tr('tap_to_change'),
            value: _groups,
            onChanged: (v) => setState(() => _groups = v),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _switchRow(
            icon: Icons.campaign_outlined,
            title: tr('channels'),
            subtitle: tr('tap_to_change'),
            value: _channels,
            onChanged: (v) => setState(() => _channels = v),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _switchRow(
            icon: Icons.play_circle_outline_rounded,
            title: tr('stories'),
            subtitle: tr('stories_subtitle'),
            value: _stories,
            onChanged: (v) => setState(() => _stories = v),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          _switchRow(
            icon: Icons.favorite_border_rounded,
            title: tr('reactions'),
            subtitle: tr('reactions_subtitle'),
            value: _reactions,
            onChanged: (v) => setState(() => _reactions = v),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Tg.textDim, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Tg.textDim)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF55A5EB),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCallsCard(BuildContext context) {
    return _buildCard(
      header: tr('calls'),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              final options = ['Default', 'Strong', 'Short', 'Disabled'];
              final idx = (options.indexOf(_vibrate) + 1) % options.length;
              setState(() => _vibrate = options[idx]);
              TgToast.show(context, '${tr('vibrate')}: $_vibrate');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('vibrate'), style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
                  Text(_vibrate, style: const TextStyle(fontSize: 13, color: Color(0xFF55A5EB))),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          InkWell(
            onTap: () {
              CallSoundService.startIncomingRingtone();
              TgToast.show(context, tr('playing_ringtone'));
              Future.delayed(const Duration(seconds: 3), () {
                CallSoundService.stop();
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('ringtone'), style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
                  Row(
                    children: [
                      Text(_ringtone, style: const TextStyle(fontSize: 13, color: Color(0xFF55A5EB))),
                      const SizedBox(width: 4),
                      const Icon(Icons.volume_up_rounded, size: 16, color: Color(0xFF55A5EB)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard() {
    return _buildCard(
      header: tr('badge_counter'),
      child: Column(
        children: [
          SwitchListTile(
            value: _badgeIcon,
            activeThumbColor: const Color(0xFF55A5EB),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('badge_icon'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            onChanged: (v) => setState(() => _badgeIcon = v),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          SwitchListTile(
            value: _includeMuted,
            activeThumbColor: const Color(0xFF55A5EB),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('include_muted'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            onChanged: (v) => setState(() => _includeMuted = v),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          SwitchListTile(
            value: _countUnread,
            activeThumbColor: const Color(0xFF55A5EB),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('count_unread'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            onChanged: (v) => setState(() => _countUnread = v),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsCard() {
    return _buildCard(
      header: tr('events'),
      child: Column(
        children: [
          SwitchListTile(
            value: _contactJoined,
            activeThumbColor: const Color(0xFF55A5EB),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('contact_joined'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            onChanged: (v) => setState(() => _contactJoined = v),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          SwitchListTile(
            value: _pinnedMessages,
            activeThumbColor: const Color(0xFF55A5EB),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('pinned_messages'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            onChanged: (v) => setState(() => _pinnedMessages = v),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherCard() {
    return _buildCard(
      header: tr('other'),
      child: Column(
        children: [
          SwitchListTile(
            value: _keepAlive,
            activeThumbColor: const Color(0xFF55A5EB),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('keep_alive'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            onChanged: (v) => setState(() => _keepAlive = v),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          SwitchListTile(
            value: _bgConnection,
            activeThumbColor: const Color(0xFF55A5EB),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('background_conn'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            onChanged: (v) => setState(() => _bgConnection = v),
          ),
        ],
      ),
    );
  }
}
