import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../data/models/tg_chat.dart';
import '../../../data/tdlib/tdlib_service.dart';
import '../../ai_copilot/models/contact_dossier.dart';
import '../services/chat_export_service.dart';

class ChatExportDialog extends StatefulWidget {
  const ChatExportDialog({
    super.key,
    required this.chat,
    this.initialType = ExportContentType.advisorProfile,
  });

  final TgChat chat;
  final ExportContentType initialType;

  static Future<void> show(
    BuildContext context,
    TgChat chat, {
    ExportContentType initialType = ExportContentType.advisorProfile,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => ChatExportDialog(
        chat: chat,
        initialType: initialType,
      ),
    );
  }

  @override
  State<ChatExportDialog> createState() => _ChatExportDialogState();
}

class _ChatExportDialogState extends State<ChatExportDialog> {
  late ExportContentType _selectedType;
  ExportFormat _selectedFormat = ExportFormat.text;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  List<TgMessage> _resolveMessages() {
    final live = TdlibService.instance.messagesOf(widget.chat.id).value.messages;
    if (live.isNotEmpty) return live;
    return widget.chat.messages;
  }

  ContactDossier _resolveDossier() {
    return ContactDossierStore.instance.getDossier(widget.chat.id).value;
  }

  String _generateText() {
    return ChatExportService.instance.generateExportText(
      chat: widget.chat,
      dossier: _resolveDossier(),
      messages: _resolveMessages(),
      type: _selectedType,
      format: _selectedFormat,
    );
  }

  String _defaultFileName() {
    final ext = _selectedFormat == ExportFormat.json ? 'json' : 'txt';
    final prefix = _selectedType == ExportContentType.advisorProfile
        ? 'advisor_profile'
        : _selectedType == ExportContentType.chatHistory
            ? 'chat_history'
            : 'full_archive';
    return '${prefix}_${widget.chat.id}.$ext';
  }

  Future<void> _copyContent(String text) async {
    await ChatExportService.instance.copyToClipboard(text);
    if (!mounted) return;
    TgToast.show(
      context,
      tr('export_copied_toast'),
      icon: Icons.content_copy_rounded,
      accentColor: const Color(0xFF8774E1),
    );
  }

  Future<void> _saveContent(String text) async {
    setState(() => _isSaving = true);
    try {
      final fileName = _defaultFileName();
      final path = await ChatExportService.instance.saveToFile(
        fileName: fileName,
        content: text,
      );
      if (!mounted) return;
      TgToast.show(
        context,
        tr('export_file_saved', {'path': path}),
        icon: Icons.download_done_rounded,
        accentColor: const Color(0xFF4FAAFF),
      );
    } catch (e) {
      if (!mounted) return;
      TgToast.show(
        context,
        tr('export_save_error', {'error': e.toString()}),
        icon: Icons.error_outline_rounded,
        accentColor: Tg.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentText = _generateText();
    final messageCount = _resolveMessages().where((m) => m.kind != MessageKind.unreadDivider && m.kind != MessageKind.date).length;

    return Dialog(
      backgroundColor: const Color(0xFF212D3B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildTypeSelector(),
              const SizedBox(height: 12),
              _buildFormatRow(currentText, messageCount),
              const SizedBox(height: 10),
              Expanded(
                child: _buildPreviewContainer(currentText),
              ),
              const SizedBox(height: 16),
              _buildActions(currentText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF8774E1).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.badge_outlined,
            color: Color(0xFF8774E1),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('export_dialog_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.chat.title}${widget.chat.headerSubtitle.isNotEmpty ? ' • ${widget.chat.headerSubtitle}' : ''}',
                style: const TextStyle(
                  color: Tg.textDim,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Tg.textDim, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          splashRadius: 18,
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18222D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTypeTab(
            title: tr('export_tab_advisor'),
            type: ExportContentType.advisorProfile,
          ),
          _buildTypeTab(
            title: tr('export_tab_chat'),
            type: ExportContentType.chatHistory,
          ),
          _buildTypeTab(
            title: tr('export_tab_all'),
            type: ExportContentType.fullArchive,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({required String title, required ExportContentType type}) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2B3A4C) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Tg.textDim,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatRow(String text, int messageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              tr('export_format_label'),
              style: const TextStyle(color: Tg.textDim, fontSize: 12),
            ),
            _buildFormatChip('TXT / Markdown', ExportFormat.text),
            const SizedBox(width: 6),
            _buildFormatChip('JSON', ExportFormat.json),
          ],
        ),
        Text(
          tr('export_stats_chars_msgs', {'chars': text.length.toString(), 'msgs': messageCount.toString()}),
          style: const TextStyle(color: Tg.textDim, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _buildFormatChip(String label, ExportFormat format) {
    final isSelected = _selectedFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8774E1).withValues(alpha: 0.25)
              : const Color(0xFF18222D),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8774E1).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFB1A4FF) : Tg.textDim,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContainer(String text) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141C24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(14),
      child: SelectionArea(
        child: SingleChildScrollView(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFDFE6EE),
              fontSize: 12.5,
              height: 1.45,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(String text) {
    return Row(
      children: [
        Expanded(
          child: Text(
            tr('export_advisor_hint'),
            style: const TextStyle(color: Tg.textFaint, fontSize: 11.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 14),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(tr('export_copy_btn')),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB1A4FF),
            side: BorderSide(color: const Color(0xFF8774E1).withValues(alpha: 0.45)),
            backgroundColor: const Color(0xFF8774E1).withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _copyContent(text),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded, size: 16),
          label: Text(tr('export_save_btn')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3390EC),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          onPressed: _isSaving ? null : () => _saveContent(text),
        ),
      ],
    );
  }
}
