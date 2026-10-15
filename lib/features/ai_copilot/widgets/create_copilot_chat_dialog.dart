import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../models/ai_settings_model.dart';
import '../models/copilot_session.dart';
import '../services/copilot_session_store.dart';

/// Диалог создания нового чата/агента Copilot.
class CreateCopilotChatDialog extends StatefulWidget {
  const CreateCopilotChatDialog({super.key});

  static Future<CopilotSession?> show(BuildContext context) {
    return showDialog<CopilotSession>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => const CreateCopilotChatDialog(),
    );
  }

  @override
  State<CreateCopilotChatDialog> createState() => _CreateCopilotChatDialogState();
}

class _CreateCopilotChatDialogState extends State<CreateCopilotChatDialog> {
  late final TextEditingController _titleController;
  final _roleController = TextEditingController(text: 'General Copilot');
  final _promptController = TextEditingController();

  IconData _selectedIcon = Icons.auto_awesome;
  Color _selectedColor = Tg.accent;
  String? _selectedModel;

  static const List<Color> _colorPalette = [
    Tg.accent,
    Tg.accentDark,
    Color(0xFF51B2FF),
    Color(0xFF00C48C),
    Color(0xFFFF9F43),
    Color(0xFFFF7675),
    Color(0xFF20BF6B),
    Color(0xFF45AAF2),
  ];

  static const List<IconData> _iconPalette = [
    Icons.auto_awesome,
    Icons.work_outline_rounded,
    Icons.analytics_outlined,
    Icons.code_rounded,
    Icons.edit_note_rounded,
    Icons.psychology_outlined,
    Icons.search_rounded,
    Icons.forum_outlined,
    Icons.smart_toy_outlined,
    Icons.terminal_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: I18n.instance.isRu ? 'Новый диалог' : 'New Chat',
    );
    _selectedModel = AiSettingsStore.instance.settings.value.model;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _roleController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final role = _roleController.text.trim();
    if (title.isEmpty) return;

    final session = CopilotSessionStore.instance.createSession(
      title: title,
      role: role.isEmpty ? 'Custom Agent' : role,
      prompt: _promptController.text.trim(),
      model: _selectedModel,
      icon: _selectedIcon,
      color: _selectedColor,
    );

    Navigator.of(context).pop(session);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Tg.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Tg.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _selectedColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _selectedColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(_selectedIcon, color: _selectedColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('new_copilot_chat_title'),
                        style: Tg.title,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('create_context_desc'),
                        style: Tg.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Tg.textDim, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Форма
            Expanded(
              child: ListView(
                children: [
                  _buildField(
                    label: tr('chat_name_task_label'),
                    controller: _titleController,
                    hint: tr('chat_name_task_hint'),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: tr('agent_role_label'),
                    controller: _roleController,
                    hint: 'Lead Hunter / CRM Analyst / Code Reviewer',
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: tr('directives_label'),
                    controller: _promptController,
                    hint: tr('directives_hint'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),

                  // Выбор иконки
                  Text(tr('agent_icon_label'), style: const TextStyle(fontSize: 12, color: Tg.textDim)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _iconPalette.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final ic = _iconPalette[i];
                        final active = ic == _selectedIcon;
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _selectedIcon = ic),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: active ? _selectedColor : Tg.field,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: active ? Colors.white : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Icon(ic, size: 20, color: active ? Colors.white : Tg.textDim),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Выбор цвета
                  Text(tr('color_accent_label'), style: const TextStyle(fontSize: 12, color: Tg.textDim)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colorPalette.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final c = _colorPalette[i];
                        final active = c == _selectedColor;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _selectedColor = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: active ? Colors.white : Colors.transparent,
                                width: active ? 2.5 : 0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Кнопки
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('cancel'), style: const TextStyle(color: Tg.textDim)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor == Tg.accent ? Tg.accentDark : _selectedColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Tg.border),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _submit,
                  icon: const Icon(Icons.add_comment_rounded, size: 16),
                  label: Text(
                    tr('create_chat_btn'),
                    style: const TextStyle(fontWeight: Tg.fontMedium, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Tg.caption),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Tg.border),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 13, color: Tg.text),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(color: Tg.textFaint, fontSize: 12.5),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}
