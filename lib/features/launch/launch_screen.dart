import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../services/gate/launch_gate.dart';
import '../../shared/art.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/cabin_widgets.dart';
import 'document_view.dart';

class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  var _started = false;
  var _entering = false;
  String? _documentUrl;
  var _showAccept = false;
  var _pageReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started) return;
      _started = true;
      _boot();
    });
  }

  Future<void> _boot() async {
    final decision = await LaunchGate.resolve();
    if (!mounted || _entering) return;
    switch (decision) {
      case OfferDecision(:final url):
        setState(() {
          _documentUrl = url;
          _showAccept = false;
        });
      case PolicyDecision():
        setState(() {
          _documentUrl = LaunchGate.policyUrl;
          _showAccept = true;
        });
      case AppDecision():
        await _enterApp();
    }
  }

  Future<void> _enterApp() async {
    if (_entering) return;
    _entering = true;
    if (mounted && _documentUrl != null) {
      setState(() => _documentUrl = null);
    }
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    if (!mounted) return;
    await ref.read(appProvider.notifier).boot(context);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _markPageReady() {
    if (!mounted || _pageReady) return;
    setState(() => _pageReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final url = _documentUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          FullScreenDocument(
            url: url,
            onAccept: _showAccept ? () => unawaited(_enterApp()) : null,
            onReady: _markPageReady,
          ),
        if (url == null || !_pageReady)
          const _LaunchLoading(key: ValueKey('launch-loading')),
      ],
    );
  }
}

class _LaunchLoading extends StatefulWidget {
  const _LaunchLoading({super.key});

  @override
  State<_LaunchLoading> createState() => _LaunchLoadingState();
}

class _LaunchLoadingState extends State<_LaunchLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CabinBackground(
        asset: Art.homeBackground,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LOADING',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    return _SignalIndicator(t: _pulse.value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignalIndicator extends StatelessWidget {
  const _SignalIndicator({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    const width = 88.0;
    final travel = (math.sin(t * math.pi * 2) + 1) / 2;
    final glow = 0.07 + travel * 0.05;
    return SizedBox(
      width: width,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 72,
            height: 28,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: glow),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Container(
            width: width,
            height: 1,
            color: AppColors.steel.withValues(alpha: 0.7),
          ),
          Align(
            alignment: Alignment((travel * 2) - 1, 0),
            child: Container(
              width: 12,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.beam.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
