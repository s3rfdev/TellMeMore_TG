import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/tg_theme.dart';
import '../../../core/widgets/tg_toast.dart';
import '../../../state/app_state.dart';
import '../models/ai_settings_model.dart';
import '../models/copilot_session.dart';
import '../services/ai_model_service.dart';
import '../services/copilot_prompt_builder.dart';
import '../services/copilot_session_store.dart';
import '../services/voice_transcription_service.dart';
import '../widgets/copilot_header.dart';
import '../widgets/copilot_input_bar.dart';
import '../widgets/copilot_message_bubble.dart';
import '../widgets/copilot_prompt_editor_dialog.dart';
import '../widgets/copilot_quick_actions.dart';
import '../widgets/copilot_sandwich_inspector_dialog.dart';
import '../widgets/copilot_summary_banner.dart';
import '../widgets/copilot_thinking_bubble.dart';

/// Экран активного чата с выбранным Copilot-агентом.
class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({
    super.key,
    this.showBack = false,
    this.onBack,
  });

  final bool showBack;
  final VoidCallback? onBack;

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isLoading = false;
  String? _loadingStatusText;
  String? _lastUserQuery;

  bool _isRecordingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _voicePath;

  String? _attachedFilePath;
  String? _attachedFileName;
  bool _isAttachedImage = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startVoice() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          TgToast.show(
            context,
            tr('no_mic_permission'),
            icon: Icons.mic_off_rounded,
          );
        }
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/copilot_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
        path: path,
      );
      setState(() {
        _isRecordingVoice = true;
        _recordSeconds = 0;
        _voicePath = path;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (mounted) {
        TgToast.show(
          context,
          tr('recording_error', {'error': e.toString()}),
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _stopVoice({required bool send, required CopilotSession session}) async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    final finalPath = path ?? _voicePath;
    final sec = _recordSeconds;

    setState(() {
      _isRecordingVoice = false;
      _recordSeconds = 0;
      _voicePath = null;
    });

    if (send && finalPath != null && (sec > 0 || (File(finalPath).existsSync() && File(finalPath).lengthSync() > 1000))) {
      final isRu = I18n.instance.isRu;

      // 1. СРАЗУ добавляем сообщение пользователя в чат (мгновенный отклик в UI)
      final placeholderText = isRu
          ? '🎤 Голосовое сообщение ($sec с)... [Распознавание речи]'
          : '🎤 Voice message (${sec}s)... [Transcribing speech]';

      final voiceUserMsg = CopilotMessage(
        text: placeholderText,
        isUser: true,
        attachmentPath: finalPath,
        attachmentName: 'voice_${sec}s.m4a',
      );

      CopilotSessionStore.instance.addMessage(session.id, voiceUserMsg);
      _scrollToBottom();

      // 2. СРАЗУ включаем статус-спиннер распознавания речи
      setState(() {
        _isLoading = true;
        _loadingStatusText = isRu
            ? '🎤 Распознавание речи ($sec с)...'
            : '🎤 Transcribing speech (${sec}s)...';
      });
      AppState.aiProcessingStatus.value = _loadingStatusText;

      try {
        final transcription = await VoiceTranscriptionService.instance.transcribeVoiceFile(
          filePath: finalPath,
          durationSeconds: sec,
        );

        if (transcription.isNotEmpty && !transcription.startsWith('[')) {
          // 3. Заменяем текст сообщения в чате на реальный распознанный текст
          final updatedMsg = voiceUserMsg.copyWith(text: transcription);
          CopilotSessionStore.instance.updateMessage(session.id, voiceUserMsg.id, updatedMsg);
          _lastUserQuery = transcription;

          // 4. Плавно переводим статус в подготовку контекста и запускаем генерацию ответа агента
          setState(() {
            _loadingStatusText = isRu ? '🧠 Подготовка контекста диалога...' : '🧠 Preparing context...';
          });
          AppState.aiProcessingStatus.value = _loadingStatusText;

          await _processAiResponse(session, updatedMsg);
        } else {
          final failedMsg = voiceUserMsg.copyWith(
            text: isRu
                ? '🎤 Голосовое сообщение ($sec с) [Не удалось распознать речь]'
                : '🎤 Voice message (${sec}s) [Could not transcribe speech]',
            isError: true,
          );
          CopilotSessionStore.instance.updateMessage(session.id, voiceUserMsg.id, failedMsg);
          setState(() {
            _isLoading = false;
            _loadingStatusText = null;
          });
          AppState.aiProcessingStatus.value = null;
          if (mounted) {
            TgToast.show(
              context,
              isRu ? 'Не удалось распознать речь' : 'Could not transcribe speech',
              icon: Icons.warning_amber_rounded,
            );
          }
        }
      } catch (e) {
        final failedMsg = voiceUserMsg.copyWith(
          text: isRu ? '🎤 Ошибка распознавания речи: $e' : '🎤 Speech recognition error: $e',
          isError: true,
        );
        CopilotSessionStore.instance.updateMessage(session.id, voiceUserMsg.id, failedMsg);
        setState(() {
          _isLoading = false;
          _loadingStatusText = null;
        });
        AppState.aiProcessingStatus.value = null;
        if (mounted) {
          TgToast.show(context, 'Ошибка STT: $e', icon: Icons.error_outline_rounded);
        }
      }
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'webp', 'gif',
          'pdf', 'txt', 'csv', 'json', 'md', 'doc', 'docx',
        ],
      );
      if (result.isNotEmpty && result.first.path != null) {
        final path = result.first.path!;
        final name = result.first.name;
        final ext = path.toLowerCase().split('.').last;
        final isImg = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
        setState(() {
          _attachedFilePath = path;
          _attachedFileName = name;
          _isAttachedImage = isImg;
        });
      }
    } catch (e) {
      if (mounted) TgToast.show(context, 'Ошибка выбора файла: $e');
    }
  }

  void _sendMessage(
    CopilotSession session,
    String text, {
    String? attachmentPath,
    String? attachmentName,
    bool? isImageAttachment,
  }) async {
    final attachedPath = attachmentPath ?? _attachedFilePath;
    final attachedName = attachmentName ?? _attachedFileName;
    final isImg = isImageAttachment ?? _isAttachedImage;
    final isRu = I18n.instance.isRu;

    var query = text.trim();
    if (query.isEmpty) {
      if (attachedPath != null) {
        query = isImg
            ? (isRu ? 'Опиши это изображение и ответь на ключевые вопросы по нему.' : 'Describe this image and analyze its key details.')
            : (isRu ? 'Проанализируй прикрепленный документ.' : 'Analyze this attached document.');
      } else {
        return;
      }
    }

    _lastUserQuery = query;
    _controller.clear();
    setState(() {
      _attachedFilePath = null;
      _attachedFileName = null;
      _isAttachedImage = false;
      _isLoading = true;
      _loadingStatusText = isRu ? '🧠 Подготовка контекста диалога...' : '🧠 Preparing context...';
    });
    AppState.aiProcessingStatus.value = _loadingStatusText;

    final userMsg = CopilotMessage(
      text: query,
      isUser: true,
      attachmentPath: attachedPath,
      attachmentName: attachedName,
      isImageAttachment: isImg,
    );

    CopilotSessionStore.instance.addMessage(session.id, userMsg);
    _scrollToBottom();

    await _processAiResponse(session, userMsg);
  }

  Future<void> _processAiResponse(CopilotSession session, CopilotMessage userMsg) async {
    final attachedPath = userMsg.attachmentPath;
    final attachedName = userMsg.attachmentName;
    final isImg = userMsg.isImageAttachment;
    final isRu = I18n.instance.isRu;
    final query = userMsg.text;

    try {
      String effectiveQuery = query;
      if (attachedPath != null && !isImg) {
        try {
          final f = File(attachedPath);
          if (f.existsSync()) {
            final len = f.lengthSync();
            if (len < 64000) {
              final content = await f.readAsString();
              effectiveQuery = '[Файл: $attachedName]\n```\n$content\n```\n\n$query';
            } else {
              effectiveQuery = '[Файл: $attachedName (размер: ${len ~/ 1024} КБ)]\n\n$query';
            }
          }
        } catch (_) {}
      }

      final settings = AiSettingsStore.instance.settings.value;
      final compressedBefore = CopilotSessionStore.instance.checkAndAutoCompress(session.id, settings);
      if (compressedBefore && mounted) {
        TgToast.show(
          context,
          isRu
              ? '🗜️ Автокомпрессия сработала: контекст сжат по объёму'
              : '🗜️ Auto-compression triggered: context compressed',
        );
      }

      final conversationHistory = <Map<String, String>>[];
      for (final m in session.messages) {
        if (identical(m, userMsg)) continue;
        conversationHistory.add({
          'role': m.isUser ? 'user' : 'model',
          'content': m.text,
        });
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final matchedChat = CopilotPromptBuilder.instance.resolveTargetChat(
        session: session,
        userQuery: query,
        activeChatId: AppState.selectedChatId.value,
      );

      final promptResult = await CopilotPromptBuilder.instance.buildSandwichPrompt(
        session: session,
        settings: settings,
        query: effectiveQuery,
        matchedChat: matchedChat,
        isRu: isRu,
      );

      if (mounted) {
        setState(() {
          _loadingStatusText = isRu
              ? '⚡ Генерация ответа нейросетью (${settings.model})...'
              : '⚡ Generating response via ${settings.model}...';
          AppState.aiProcessingStatus.value = _loadingStatusText;
        });
      }

      final reply = await AiModelService.instance.generateChatCompletion(
        prompt: effectiveQuery,
        systemPrompt: promptResult.systemPrompt,
        history: conversationHistory,
        settings: settings,
        imagePath: (attachedPath != null && isImg) ? attachedPath : null,
      );

      final agentMsg = CopilotMessage(
        text: reply,
        isUser: false,
        toolName: promptResult.toolName,
        toolOutput: promptResult.toolOutput,
      );

      CopilotSessionStore.instance.addMessage(session.id, agentMsg);
      CopilotSessionStore.instance.checkAndAutoCompress(session.id, settings);
    } catch (e) {
      if (mounted) {
        final errorText = isRu
            ? '⚠️ Не удалось получить ответ от нейросети.\nПричина: $e\n\nПроверьте подключение к сети и ключ API в Настройках.'
            : '⚠️ Failed to receive response from AI model.\nReason: $e\n\nPlease check network connection and API key in Settings.';
        final errAgentMsg = CopilotMessage(
          text: errorText,
          isUser: false,
          isError: true,
        );
        CopilotSessionStore.instance.addMessage(session.id, errAgentMsg);
        TgToast.show(
          context,
          isRu ? '⚠️ Ошибка запроса к нейросети' : '⚠️ AI request error',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingStatusText = null;
        });
        _scrollToBottom();
      }
      AppState.aiProcessingStatus.value = null;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: CopilotSessionStore.instance.activeSessionId,
      builder: (context, activeId, _) {
        return ValueListenableBuilder<List<CopilotSession>>(
          valueListenable: CopilotSessionStore.instance.sessions,
          builder: (context, sessions, _) {
            final session = CopilotSessionStore.instance.activeSession;
            final settings = AiSettingsStore.instance.settings.value;

            return Scaffold(
              backgroundColor: Tg.bg,
              body: SafeArea(
                child: Column(
                  children: [
                    CopilotHeader(
                      session: session,
                      settings: settings,
                      showBack: widget.showBack,
                      onBack: widget.onBack,
                      onOpenInspector: () {
                        CopilotSandwichInspectorDialog.show(
                          context,
                          session: session,
                          settings: settings,
                          currentQuery: _controller.text,
                        );
                      },
                      onOpenPromptEditor: () {
                        CopilotPromptEditorDialog.show(
                          context,
                          session: session,
                          onSaved: () {
                            if (mounted) setState(() {});
                          },
                        );
                      },
                      onClearHistory: () {
                        CopilotSessionStore.instance.clearSessionMessages(session.id);
                        TgToast.show(context, tr('copilot_cleared_toast'));
                      },
                    ),
                    CopilotSummaryBanner(session: session),
                    CopilotQuickActions(
                      session: session,
                      onSelectAction: (action) => _sendMessage(session, action),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: session.messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == session.messages.length && _isLoading) {
                            return CopilotThinkingBubble(
                              session: session,
                              statusText: _loadingStatusText,
                            );
                          }
                          final msg = session.messages[index];
                          return CopilotMessageBubble(
                            session: session,
                            msg: msg,
                            lastUserQuery: _lastUserQuery,
                            isLoading: _isLoading,
                            onRetry: _lastUserQuery != null ? () => _sendMessage(session, _lastUserQuery!) : null,
                            onOpenSettings: () {
                              AppState.activeSidebarTab.value = SidebarTab.settings;
                              AppState.activeSettingsSection.value = SettingsSection.general;
                            },
                          );
                        },
                      ),
                    ),
                    CopilotInputBar(
                      session: session,
                      controller: _controller,
                      isLoading: _isLoading,
                      isRecordingVoice: _isRecordingVoice,
                      recordSeconds: _recordSeconds,
                      attachedFilePath: _attachedFilePath,
                      attachedFileName: _attachedFileName,
                      isAttachedImage: _isAttachedImage,
                      onPickAttachment: _pickAttachment,
                      onClearAttachment: () {
                        setState(() {
                          _attachedFilePath = null;
                          _attachedFileName = null;
                          _isAttachedImage = false;
                        });
                      },
                      onStartVoice: _startVoice,
                      onCancelVoice: () => _stopVoice(send: false, session: session),
                      onSendVoice: () => _stopVoice(send: true, session: session),
                      onSendMessage: (text) => _sendMessage(session, text),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
