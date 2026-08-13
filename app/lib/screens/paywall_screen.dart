import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/providers/subscription_provider.dart';
import '../platform/iap_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import '../widgets/toast_notification.dart';

/// Non-blocking. "Go Ad-Free." Comparison: Free (with ads) vs Ad-Free
/// ($0.99/mo). Restore Purchases button. No feature list — because all
/// features are free (Section 5 File 46's own stated reasoning).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isPurchasing = false;

  Future<void> _purchase(BuildContext context) async {
    setState(() => _isPurchasing = true);
    try {
      final response = await IapService.instance.queryAdFreeProduct();
      if (response.productDetails.isEmpty) {
        if (context.mounted) {
          ToastNotification.show(
            context,
            message: 'Ad-free plan is not available right now.',
            type: ToastType.error,
          );
        }
        return;
      }
      await IapService.instance.buyAdFreeSubscription(response.productDetails.first);
      // Entitlement update arrives asynchronously via subscription_
      // provider's purchaseStream listener (Phase 3) — this screen
      // doesn't need to poll or wait here.
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: 'Purchase failed.', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      await IapService.instance.restorePurchases();
      if (context.mounted) {
        ToastNotification.show(
          context,
          message: 'Restore requested — check back in a moment.',
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastNotification.show(context, message: 'Restore failed.', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Go Ad-Free'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: subscriptionProvider,
        builder: (context, isAdFree, _) {
          if (isAdFree) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text("You're already ad-free. Thank you!"),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PlanCard(
                        title: 'Free',
                        price: '\$0',
                        bullets: const ['All 14 features', 'Ad-supported'],
                        highlighted: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlanCard(
                        title: 'Ad-Free',
                        price: '\$0.99/mo',
                        bullets: const ['All 14 features', 'Zero ads'],
                        highlighted: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Go Ad-Free — \$0.99/mo',
                  isLoading: _isPurchasing,
                  onPressed: () => _purchase(context),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _restore(context),
                  child: const Text('Restore Purchases'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.bullets,
    required this.highlighted,
  });

  final String title;
  final String price;
  final List<String> bullets;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: highlighted
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(price, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(b, style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
