import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/settings/app_settings.dart';

class LegalScreen extends StatelessWidget {
  final String type;

  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isPrivacy = type == 'privacy';
    final title = isPrivacy ? context.t('privacy_policy') : context.t('terms');
    final sections = isPrivacy
        ? [
            context.t('privacy_1'),
            context.t('privacy_2'),
            context.t('privacy_3'),
            context.t('privacy_4'),
          ]
        : [
            context.t('terms_1'),
            context.t('terms_2'),
            context.t('terms_3'),
            context.t('terms_4'),
          ];

    return Scaffold(
      backgroundColor: AppColors.page(context),
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t('back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemBuilder: (_, index) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Text(
            sections[index],
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary(context),
              height: 1.45,
            ),
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: sections.length,
      ),
    );
  }
}
