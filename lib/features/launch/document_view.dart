import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../shared/theme/app_theme.dart';

class FullScreenDocument extends StatefulWidget {
  const FullScreenDocument({
    required this.url,
    this.onAccept,
    this.onReady,
    super.key,
  });

  final String url;
  final VoidCallback? onAccept;
  final VoidCallback? onReady;

  @override
  State<FullScreenDocument> createState() => _FullScreenDocumentState();
}

class _FullScreenDocumentState extends State<FullScreenDocument>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  var _ready = false;
  Timer? _reveal;

  static const _orientations = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController.fromPlatformCreationParams(
      WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        javaScriptCanOpenWindowsAutomatically: true,
      ),
    );
    _reveal = Timer(const Duration(seconds: 12), _showPage);
    unawaited(_open());
  }

  Future<void> _open() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setUserAgent(_browserUserAgent());
    final platform = _controller.platform;
    if (platform is WebKitWebViewController) {
      await platform.setAllowsBackForwardNavigationGestures(true);
    }
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) => _showPage(),
        onWebResourceError: (error) {
          if (error.isForMainFrame == false) return;
          _showPage();
        },
        onNavigationRequest: (request) {
          final scheme = Uri.tryParse(request.url)?.scheme ?? '';
          if (scheme == 'http' ||
              scheme == 'https' ||
              scheme == 'about' ||
              scheme == 'data' ||
              scheme == 'blob') {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ),
    );
    if (!mounted) return;
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  void _showPage() {
    if (_ready) return;
    _ready = true;
    _reveal?.cancel();
    unawaited(_allowRotation());
    unawaited(_immersive());
    if (!mounted) return;
    widget.onReady?.call();
  }

  Future<void> _allowRotation() {
    return SystemChrome.setPreferredOrientations(_orientations);
  }

  Future<void> _immersive() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeMetrics() {
    unawaited(_immersive());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_allowRotation());
      unawaited(_immersive());
    }
  }

  @override
  void dispose() {
    _reveal?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    final accept = widget.onAccept;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                insets.left,
                insets.top,
                insets.right,
                accept == null ? insets.bottom : 0,
              ),
              child: Column(
                children: [
                  Expanded(child: WebViewWidget(controller: _controller)),
                  if (accept != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        10,
                        16,
                        10 + insets.bottom,
                      ),
                      child: _AcceptButton(onPressed: accept),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _browserUserAgent() {
  final match = RegExp(r'(\d+)[._](\d+)')
      .firstMatch(Platform.operatingSystemVersion);
  final major = match?.group(1) ?? '18';
  final minor = match?.group(2) ?? '0';
  if (Platform.isIOS) {
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS ${major}_$minor like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/$major.$minor '
        'Mobile/15E148 Safari/604.1';
  }
  return 'Mozilla/5.0 (Linux; Android $major; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';
}

class _AcceptButton extends StatelessWidget {
  const _AcceptButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.steel),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Center(
            child: Text(
              'ACCEPT',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
      ),
    );
  }
}
