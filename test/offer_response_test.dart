import 'package:flutter_test/flutter_test.dart';
import 'package:revolt_cabino/services/gate/offer_response.dart';

void main() {
  const key = offerResponseKey;

  test('reads an http url stored under the offer key', () {
    final url = offerUrlFromBody('{"$key":"https://example.com/play"}');
    expect(url, 'https://example.com/play');
  });

  test('any other payload is not an offer', () {
    expect(
      offerUrlFromBody('{"mood":"aurora","lane":"https://x.test"}'),
      isNull,
    );
    expect(offerUrlFromBody('{"$key":"not a url"}'), isNull);
    expect(offerUrlFromBody('[]'), isNull);
    expect(offerUrlFromBody('nope'), isNull);
  });

  test('saved offer opens with no further request', () {
    expect(
      nextGateAction(savedUrl: 'https://example.com/a', claimed: true),
      GateAction.offer,
    );
  });

  test('a claimed install without a url opens the app', () {
    expect(nextGateAction(savedUrl: null, claimed: true), GateAction.app);
  });

  test('the first launch is the only post', () {
    expect(nextGateAction(savedUrl: null, claimed: false), GateAction.post);
  });
}
