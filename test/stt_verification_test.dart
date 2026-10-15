import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_answer/features/ai_copilot/models/ai_settings_model.dart';
import 'package:tg_answer/features/ai_copilot/services/voice_transcription_service.dart';

void main() {
  test('transcribes recorded user audio with Gemini STT', () async {
    const path = '/tmp/smart_reply_1792073562403.m4a';
    if (!File(path).existsSync()) {
      return;
    }

    final key = AiSettingsStore.instance.settings.value.geminiKey;
    if (key.isEmpty) {
      return;
    }

    final res = await VoiceTranscriptionService.instance.transcribeVoiceFile(
      filePath: path,
      durationSeconds: 5,
    );
    expect(res, isNotEmpty);
    expect(res.startsWith('['), isFalse);
    expect(res.toLowerCase(), contains('сейчас'));
  });
}
