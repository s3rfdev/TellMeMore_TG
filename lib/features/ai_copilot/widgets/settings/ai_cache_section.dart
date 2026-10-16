import 'package:flutter/material.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/tg_theme.dart';
import '../../../../core/widgets/tg_toast.dart';
import '../../models/ai_settings_model.dart';
import 'settings_card.dart';

/// Раздел статистики и очистки локального кэша аудиозаписей и транскрипций.
class AiCacheSection extends StatelessWidget {
  const AiCacheSection({
    super.key,
    required this.settings,
  });

  final AiSettings settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsCard(
          title: tr('ai_cache_title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('ai_cache_saved_transcripts'), style: const TextStyle(fontSize: 13, color: Tg.textDim)),
                  Text(tr('ai_cache_files_count', {'count': settings.cachedAudioCount.toString()}), style: const TextStyle(fontSize: 13, color: Tg.text)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('ai_cache_audio_size'), style: const TextStyle(fontSize: 13, color: Tg.textDim)),
                  Text(
                    '${(settings.cachedAudioSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                    style: const TextStyle(fontSize: 13, color: Tg.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  TgToast.show(context, tr('ai_cache_cleared_toast'));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3847),
                  foregroundColor: Tg.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: Text(tr('ai_cache_clear_btn')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
