import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starmory_app/data/services/quota_service.dart';
import 'package:starmory_app/presentation/pages/onboarding_page.dart';

final quotaServiceProvider = Provider<QuotaService>((ref) {
  return QuotaService(ref.watch(onboardingServiceProvider));
});

final quotaStatusProvider = FutureProvider<QuotaStatus>((ref) async {
  final service = ref.watch(quotaServiceProvider);
  return await service.getStatus();
});

class QuotaIndicator extends ConsumerWidget {
  final bool showInline;
  final VoidCallback? onUpgradeTap;

  const QuotaIndicator({
    super.key,
    this.showInline = false,
    this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(quotaStatusProvider);

    return statusAsync.when(
      data: (status) {
        // Don't show anything if quota is healthy
        if (!status.isLow && !status.isExhausted) {
          return const SizedBox.shrink();
        }

        final content = _buildContent(context, status);

        if (showInline) {
          return content;
        }

        return BannerIndicator(
          status: status,
          child: content,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(BuildContext context, QuotaStatus status) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: status.isExhausted
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.9)
            : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.isExhausted
              ? theme.colorScheme.error.withValues(alpha: 0.5)
              : theme.colorScheme.tertiary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.isExhausted ? Icons.block_rounded : Icons.warning_rounded,
            size: 16,
            color: status.isExhausted
                ? theme.colorScheme.error
                : theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Text(
            status.warningMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: status.isExhausted
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface,
            ),
          ),
          if (status.isExhausted && status.isGuest && onUpgradeTap != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onUpgradeTap,
              child: Text(
                'Sign up',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BannerIndicator extends StatelessWidget {
  final QuotaStatus status;
  final Widget child;

  const BannerIndicator({
    super.key,
    required this.status,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.isExhausted
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.isExhausted
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            status.isExhausted ? Icons.error_rounded : Icons.info_rounded,
            color: status.isExhausted
                ? theme.colorScheme.error
                : theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
