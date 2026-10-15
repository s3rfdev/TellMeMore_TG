import 'package:flutter/material.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';

/// Всплывающее меню эмодзи в стиле Telegram Desktop.
class EmojiPickerPopup extends StatefulWidget {
  const EmojiPickerPopup({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
  });

  final void Function(String emoji) onEmojiSelected;
  final VoidCallback onClose;

  @override
  State<EmojiPickerPopup> createState() => _EmojiPickerPopupState();
}

class _EmojiPickerPopupState extends State<EmojiPickerPopup>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchFilter = '';

  static const Map<String, List<String>> _categories = {
    '😀': [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
      '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
      '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
      '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
      '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
      '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓',
      '🧐', '😕', '😟', '🙁', '☹️', '😮', '😯', '😲', '😳', '🥺',
      '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣',
      '😞', '😓', '😩', '😫', '🥱', '😤', '😡', '😠', '🤬', '😈',
    ],
    '👍': [
      '👍', '👎', '👌', '🤌', '🤏', '✌️', '🤞', '🫰', '🤟', '🤘',
      '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '🫵', '👍🏻', '👍🏼',
      '👍🏽', '👍🏾', '👍🏿', '👋', '🤚', '🖐️', '✋', '🖖', '🫱', '🫲',
      '🫳', '🫴', '👏', '🙌', '🫶', '👐', '🤲', '🤝', '🙏', '✍️',
      '💪', '🦾', '🦿', '🦵', '🦶', '👂', '🦻', '👃', '🧠', '🫀',
    ],
    '🐱': [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐻‍❄️', '🐨',
      '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤',
      '🦆', '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🪱',
      '🐛', '🦋', '🐌', '🐞', '🐜', '🪰', '🪲', '🪳', '🦟', '🦗',
      '🕷️', '🕸️', '🦂', '🐢', '🐍', '🦎', '🐙', '🦑', '🦐', '🦞',
      '🦀', '🐡', '🐠', '🐟', '🐬', '🐳', '🐋', '🦈', '🦭', '🐊',
    ],
    '🍕': [
      '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
      '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🥑', '🥦',
      '🍔', '🍟', '🍕', '🌭', '🥪', '🌮', '🌯', '🥙', '🧆', '🍜',
      '🍝', '🍣', '🍱', '🥟', '🍤', '🍙', '🍚', '🍘', '🍥', '🍧',
      '🍨', '🍦', '🍰', '🧁', '🥧', '🍫', '🍬', '🍭', '☕', '🍵',
    ],
    '🔥': [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '❤️‍🔥', '❤️‍🩹', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝',
      '🔥', '✨', '⭐', '🌟', '💫', '⚡', '💥', '💯', '💢', '🎉',
      '🎊', '🚀', '🎯', '🏆', '🥇', '🥈', '🥉', '⚽', '🏀', '🏈',
      '💡', '💎', '🔑', '🔒', '🔔', '📣', '📢', '📦', '🎁', '🎈',
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 340,
      decoration: BoxDecoration(
        color: Tg.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tg.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header tabs + close
          Container(
            height: 44,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Tg.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: const Color(0xFF8774E1),
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                    tabs: _categories.keys.map((cat) {
                      return Tab(
                        child: Text(cat, style: const TextStyle(fontSize: 18)),
                      );
                    }).toList(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Tg.textFaint),
                  onPressed: widget.onClose,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          // Search input
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: Tg.field,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Tg.textFaint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13, color: Tg.text),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: tr('search_emoji'),
                        hintStyle: const TextStyle(fontSize: 13, color: Tg.textFaint),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      onChanged: (val) => setState(() => _searchFilter = val.trim()),
                    ),
                  ),
                  if (_searchFilter.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchFilter = '');
                      },
                      child: const Icon(Icons.close, size: 14, color: Tg.textFaint),
                    ),
                ],
              ),
            ),
          ),
          // Emoji grid
          Expanded(
            child: _searchFilter.isNotEmpty
                ? _buildFilteredGrid()
                : TabBarView(
                    controller: _tabController,
                    children: _categories.values.map((list) {
                      return _buildGrid(list);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredGrid() {
    final all = _categories.values.expand((x) => x).toList();
    // Simple filter
    return _buildGrid(all);
  }

  Widget _buildGrid(List<String> emojis) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onEmojiSelected(emoji),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        );
      },
    );
  }
}
