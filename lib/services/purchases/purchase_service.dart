import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../game/levels/progression.dart';
import 'grant.dart';

typedef PurchaseGrant = bool Function(
  String productId,
  String transactionId,
  bool restored,
);

class PurchaseService extends ChangeNotifier {
  PurchaseService(this._grant);

  static const _purchaseIntents = MethodChannel('revolt_cabino/purchase_intents');

  final PurchaseGrant _grant;

  InAppPurchase get _store => InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, ProductDetails> products = {};
  var available = false;
  var queryFinished = false;
  String? purchasingId;
  String? notice;
  String? success;
  final Set<String> _announced = {};

  Future<void> start() async {
    _subscription ??= _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        notice = error.toString();
        purchasingId = null;
        notifyListeners();
      },
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _bindPurchaseIntents();
    }
    try {
      available = await _store.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!available) {
      queryFinished = true;
      notice = 'The App Store is unavailable. Try again when connected.';
      notifyListeners();
      return;
    }
    try {
      final response = await _store.queryProductDetails(storeProductIds);
      products
        ..clear()
        ..addEntries(response.productDetails.map((item) => MapEntry(item.id, item)));
      if (response.error != null && products.isEmpty) {
        available = false;
        notice = 'The App Store is unavailable. Try again when connected.';
      }
    } catch (_) {
      available = false;
      notice = 'The App Store is unavailable. Try again when connected.';
    }
    queryFinished = true;
    notifyListeners();
  }

  Future<void> _bindPurchaseIntents() async {
    _purchaseIntents.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'started':
          purchasingId = call.arguments as String?;
          success = null;
          notice = null;
        case 'pending':
          purchasingId = call.arguments as String?;
          notice = 'Purchase pending approval.';
        case 'cancelled':
          if (purchasingId == call.arguments) purchasingId = null;
          notice = null;
        case 'failed':
          purchasingId = null;
          final message = call.arguments as String?;
          notice = (message == null || message.isEmpty) ? null : message;
        default:
          break;
      }
      notifyListeners();
    });
    try {
      await _purchaseIntents.invokeMethod<void>('ready');
    } catch (_) {
      // The listener is absent outside the iOS runner. Purchases inside the app still work.
    }
  }

  Future<void> buy(String productId) async {
    final product = products[productId];
    if (!available || product == null) {
      notice = 'The App Store is unavailable. Try again when connected.';
      notifyListeners();
      return;
    }
    purchasingId = productId;
    success = null;
    notice = null;
    notifyListeners();
    final param = PurchaseParam(productDetails: product);
    try {
      final started = productId == forbiddenEntitlementId
          ? await _store.buyNonConsumable(purchaseParam: param)
          : await _store.buyConsumable(purchaseParam: param);
      if (!started) {
        purchasingId = null;
        notifyListeners();
      }
    } catch (error) {
      purchasingId = null;
      notice = error.toString();
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!available) {
      notice = 'The App Store is unavailable. Try again when connected.';
      notifyListeners();
      return;
    }
    notice = null;
    notifyListeners();
    try {
      await _store.restorePurchases();
    } catch (error) {
      notice = error.toString();
      notifyListeners();
    }
  }

  void consumeSuccess() {
    success = null;
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasingId = purchase.productID;
          notice = 'Purchase pending approval.';
        case PurchaseStatus.canceled:
          if (purchasingId == purchase.productID) purchasingId = null;
          notice = null;
        case PurchaseStatus.error:
          if (purchasingId == purchase.productID) purchasingId = null;
          final message = purchase.error?.message ?? '';
          final code = purchase.error?.code ?? '';
          final canceled = code.toLowerCase().contains('cancel') ||
              message.toLowerCase().contains('cancel');
          notice = canceled ? null : (message.isEmpty ? null : message);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final transactionId = _transactionId(purchase);
          final restored = purchase.status == PurchaseStatus.restored;
          final granted = transactionId != null &&
              _grant(purchase.productID, transactionId, restored);
          if (granted && !restored && _announced.add(transactionId)) {
            success = purchase.productID == forbiddenEntitlementId
                ? 'Forbidden Sector is unlocked.'
                : 'Hint credits added.';
          }
          if (purchasingId == purchase.productID) purchasingId = null;
          notice = null;
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  String? _transactionId(PurchaseDetails purchase) {
    final id = purchase.purchaseID;
    if (id != null && id.isNotEmpty) return id;
    final local = purchase.verificationData.localVerificationData;
    if (local.isNotEmpty) return local;
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
