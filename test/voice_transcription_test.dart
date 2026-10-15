import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/features/ai_copilot/services/voice_transcription_service.dart';
import 'package:tg_answer/features/ai_copilot/services/copilot_session_store.dart';
import 'package:tg_answer/data/models/tg_chat.dart';
import 'package:tg_answer/features/chat/services/chat_export_service.dart';

void main() {
  group('VoiceTranscriptionService Tests', () {
    final service = VoiceTranscriptionService.instance;

    test('saves and retrieves transcriptions by message ID and file path', () {
      service.saveTranscription(12345, 'Здравствуйте, это тестовое голосовое.');
      expect(service.hasTranscription(12345), isTrue);
      expect(service.getCachedTranscription(12345), 'Здравствуйте, это тестовое голосовое.');

      service.saveTranscription('/tmp/voice_note.m4a', 'Вторая расшифровка.');
      expect(service.hasTranscription('/tmp/voice_note.m4a'), isTrue);
      expect(service.getCachedTranscription('/tmp/voice_note.m4a'), 'Вторая расшифровка.');
    });

    test('returns null for unknown IDs or null parameters', () {
      expect(service.getCachedTranscription(99999999), isNull);
      expect(service.getCachedTranscription(null), isNull);
      expect(service.hasTranscription(null), isFalse);
    });

    test('fallback returns formatted string if file does not exist', () async {
      final res = await service.transcribeVoiceFile(
        filePath: '/non_existent_path/audio.m4a',
        durationSeconds: 15,
      );
      expect(res, contains('15 сек'));
    });
  });

  group('CopilotSessionStore Default Persona Tests', () {
    test('default greeting does not contain hardcoded contact names like Taras', () {
      final store = CopilotSessionStore.instance;
      final session = store.sessions.value.first;
      expect(session.messages.first.text.contains('Тарасом'), isFalse);
      expect(session.messages.first.text.contains('Taras'), isFalse);
    });
  });

  group('ChatExportService Voice Transcription Integration Tests', () {
    test('voice notes include cached transcriptions when exported', () {
      const chatId = '999';
      const msgId = 55555;
      VoiceTranscriptionService.instance.saveTranscription(msgId, 'Договорились созвониться в 15:00');

      const chat = TgChat(
        id: chatId,
        title: 'Тестовый Партнер',
        avatarEmoji: '👤',
        avatarColor: 0xFF5288C1,
        sender: 'Тестовый Партнер',
        preview: 'Привет',
        time: '12:00',
        headerSubtitle: 'online',
      );

      final msg = const TgMessage(
        id: msgId,
        kind: MessageKind.voice,
        duration: 22,
        outgoing: false,
      );

      final exported = ChatExportService.instance.formatChatHistory(chat, [msg]);
      expect(exported, contains('22 сек'));
      expect(exported, contains('Договорились созвониться в 15:00'));
    });
  });
}
