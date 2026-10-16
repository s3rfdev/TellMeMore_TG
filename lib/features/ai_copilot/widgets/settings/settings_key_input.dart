import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../../../core/widgets/tg_toast.dart';

/// Поле ввода API ключа или URL с маскировкой пароля и кнопкой копирования.
class SettingsKeyInput extends StatefulWidget {
  const SettingsKeyInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isPassword = true,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool isPassword;

  @override
  State<SettingsKeyInput> createState() => _SettingsKeyInputState();
}

class _SettingsKeyInputState extends State<SettingsKeyInput> {
  late bool _obscure;
  late String _currentValue;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(SettingsKeyInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 12.5, color: Tg.textDim)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Tg.field,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: widget.value,
                  obscureText: _obscure,
                  style: const TextStyle(fontSize: 13, color: Tg.text, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) {
                    _currentValue = v;
                    widget.onChanged(v);
                  },
                ),
              ),
              if (widget.isPassword)
                IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18,
                    color: Tg.textDim,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure
                      ? (I18n.instance.isRu ? 'Показать ключ' : 'Show key')
                      : (I18n.instance.isRu ? 'Скрыть ключ' : 'Hide key'),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: Tg.textDim),
                onPressed: () {
                  if (_currentValue.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: _currentValue));
                    TgToast.show(
                      context,
                      I18n.instance.isRu ? 'Ключ скопирован в буфер' : 'Key copied to clipboard',
                      icon: Icons.check_circle_rounded,
                    );
                  }
                },
                tooltip: I18n.instance.isRu ? 'Скопировать ключ' : 'Copy key',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
