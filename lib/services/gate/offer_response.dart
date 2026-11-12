import 'dart:convert';

const offerResponseKey = 'a7dfac23-a360-4f98-bc49-71a32285909f';

enum GateAction { offer, app, post }

String? httpUrl(String? raw) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri.toString();
}

String? offerUrlFromBody(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final value = decoded[offerResponseKey];
    if (value is! String) return null;
    return httpUrl(value);
  } catch (_) {
    return null;
  }
}

GateAction nextGateAction({String? savedUrl, required bool claimed}) {
  if (httpUrl(savedUrl) != null) return GateAction.offer;
  if (claimed) return GateAction.app;
  return GateAction.post;
}
