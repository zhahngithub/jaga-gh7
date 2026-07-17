import 'package:flutter/material.dart';
import 'package:jaga/core/theme/app_colors.dart';

import '../models/mock_contribution_data.dart';
import 'profile_components.dart';

class ProfileContributionSection extends StatelessWidget {
  const ProfileContributionSection({
    required this.data,
    required this.onCreateReport,
    required this.onOpenMyReports,
    required this.onConfirmReport,
    super.key,
  });

  final MockContributionData data;
  final VoidCallback onCreateReport;
  final VoidCallback onOpenMyReports;
  final VoidCallback onConfirmReport;

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Kontribusi kamu',
      icon: Icons.volunteer_activism_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ImpactSummary(data: data),
          const SizedBox(height: 22),
          Text(
            'Aktivitas kontribusi',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _ContributionStatRow(
            icon: Icons.fact_check_outlined,
            label: '${data.confirmedReports} laporan dikonfirmasi',
          ),
          _ContributionStatRow(
            icon: Icons.schedule_rounded,
            label: data.pendingReports == 0
                ? 'Tidak ada laporan menunggu konfirmasi'
                : '${data.pendingReports} laporan menunggu konfirmasi',
          ),
          _ContributionStatRow(
            icon: Icons.people_alt_outlined,
            label: data.helperResponses == 0
                ? 'Belum ada respons bantuan untuk pengguna sekitar'
                : '${data.helperResponses} kali membantu pengguna sekitar',
          ),
          const Divider(height: 32),
          Text(
            'Aksi kontribusi',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          _ContributionActionRow(
            icon: Icons.add_location_alt_outlined,
            label: 'Buat laporan',
            onTap: onCreateReport,
          ),
          const Divider(height: 1),
          _ContributionActionRow(
            icon: Icons.article_outlined,
            label: 'Laporan saya',
            onTap: onOpenMyReports,
          ),
          const Divider(height: 1),
          _ContributionActionRow(
            icon: Icons.task_alt_rounded,
            label: 'Konfirmasi laporan',
            onTap: onConfirmReport,
          ),
        ],
      ),
    );
  }
}

class _ImpactSummary extends StatelessWidget {
  const _ImpactSummary({required this.data});

  final MockContributionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.diversity_1_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dampak kontribusimu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Kamu telah membantu ${data.helpedCount} orang',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Terima kasih telah membantu membuat perjalanan komunitas Jaga menjadi lebih aman.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionStatRow extends StatelessWidget {
  const _ContributionStatRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ContributionActionRow extends StatelessWidget {
  const _ContributionActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
