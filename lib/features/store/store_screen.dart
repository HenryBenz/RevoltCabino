import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../game/levels/progression.dart';
import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/cabin_widgets.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({required this.focusForbidden, super.key});

  final bool focusForbidden;

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final _forbiddenKey = GlobalKey();
  var _shownSuccess = '';

  @override
  void initState() {
    super.initState();
    if (widget.focusForbidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealForbidden());
    }
  }

  void _revealForbidden() {
    final target = _forbiddenKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target, alignment: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    if (app == null) return const Scaffold(backgroundColor: AppColors.background);
    final purchases = app.purchases;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CabinBackground(
        asset: Art.storeBackground,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: purchases,
            builder: (context, child) {
              _presentSuccess(purchases.success);
              final owned = app.catalog.ownsForbidden(app.save);
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    ScreenHeader(
                      title: 'SUPPLY TERMINAL',
                      onBack: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          _CopyPlate(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'The full main campaign is playable without purchases.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (!purchases.available && purchases.queryFinished) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'The App Store is unavailable. Try again when connected.',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                                if (purchases.notice != null &&
                                    purchases.notice !=
                                        'The App Store is unavailable. Try again when connected.') ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    purchases.notice!,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            key: _forbiddenKey,
                            child: _ForbiddenCard(
                              owned: owned,
                              price: purchases.products[forbiddenEntitlementId]?.price,
                              processing: purchases.purchasingId == forbiddenEntitlementId,
                              onUnlock: () => purchases.buy(forbiddenEntitlementId),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              const SizedBox(
                                width: 42,
                                height: 42,
                                child: CabinImage(Art.analysis),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'HINT CREDITS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final pack in _packs) ...[
                            _PackCard(
                              name: pack.$1,
                              credits: pack.$2,
                              price: purchases.products[pack.$3]?.price,
                              processing: purchases.purchasingId == pack.$3,
                              onBuy: () => purchases.buy(pack.$3),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          CabinButton(
                            label: 'RESTORE PURCHASES',
                            onPressed: purchases.restore,
                          ),
                          const SizedBox(height: 12),
                          const _CopyPlate(
                            child: Text(
                              'Restores permanent content. Consumable hint balances are stored on this device and are not restored as permanent purchases.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _presentSuccess(String? success) {
    if (success == null) {
      _shownSuccess = '';
      return;
    }
    if (success == _shownSuccess || !mounted) return;
    _shownSuccess = success;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showCabinMessage(context, success);
      if (mounted) ref.read(appProvider)?.purchases.consumeSuccess();
    });
  }
}

class _CopyPlate extends StatelessWidget {
  const _CopyPlate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
          child: child,
        ),
      ),
    );
  }
}

const _packs = <(String, int, String)>[
  ('Small Analysis Pack', 5, 'revolt_cabino.hints_5'),
  ('Medium Analysis Pack', 15, 'revolt_cabino.hints_15'),
  ('Large Analysis Pack', 40, 'revolt_cabino.hints_40'),
];

class _ForbiddenCard extends StatelessWidget {
  const _ForbiddenCard({
    required this.owned,
    required this.price,
    required this.processing,
    required this.onUnlock,
  });

  final bool owned;
  final String? price;
  final bool processing;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final label = owned
        ? 'OWNED'
        : processing
        ? 'PROCESSING'
        : 'UNLOCK';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.steel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: const AspectRatio(
                aspectRatio: 1.5,
                child: CabinImage(Art.forbidden, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Forbidden Sector',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Ten additional handcrafted chambers.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '“Brushed Steel” cabin finish.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (price != null) ...[
              const SizedBox(height: 8),
              TechnicalLabel(price!),
            ],
            const SizedBox(height: 12),
            CabinButton(
              label: label,
              filled: !owned,
              onPressed: owned || processing || price == null ? null : onUnlock,
            ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.name,
    required this.credits,
    required this.price,
    required this.processing,
    required this.onBuy,
  });

  final String name;
  final int credits;
  final String? price;
  final bool processing;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey(name),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.steel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            TechnicalLabel('$credits'),
            if (price != null) ...[
              const SizedBox(height: 6),
              TechnicalLabel(price!),
            ],
            const SizedBox(height: 12),
            CabinButton(
              label: processing ? 'PROCESSING' : 'BUY',
              filled: true,
              onPressed: processing || price == null ? null : onBuy,
            ),
          ],
        ),
      ),
    );
  }
}
