import Flutter
import StoreKit

/// Listens for purchases that start outside the app: promoted products on the
/// App Store page, and win-back offers. The purchase itself is started here.
/// Granting content and finishing the transaction stay on the Flutter purchase
/// stream, which already observes StoreKit 2 `Transaction.updates`.
final class PurchaseIntentListener: NSObject, SKPaymentTransactionObserver {
  static let shared = PurchaseIntentListener()

  private let knownProducts: Set<String> = [
    "revolt_cabino.forbidden_sector",
    "revolt_cabino.hints_5",
    "revolt_cabino.hints_15",
    "revolt_cabino.hints_40",
  ]

  private var channel: FlutterMethodChannel?
  private var dartReady = false
  private var listening = false
  private var pendingPayments: [SKPayment] = []
  private var readyWaiters: [CheckedContinuation<Void, Never>] = []

  func start() {
    guard !listening else { return }
    listening = true
    if #available(iOS 16.4, *) {
      Task { @MainActor in
        for await intent in PurchaseIntent.intents {
          await self.handle(intent)
        }
      }
    } else {
      SKPaymentQueue.default().add(self)
    }
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "revolt_cabino/purchase_intents",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "ready" else {
        result(FlutterMethodNotImplemented)
        return
      }
      Task { @MainActor in
        self?.markReady()
        result(nil)
      }
    }
  }

  @available(iOS 16.4, *)
  @MainActor
  private func handle(_ intent: PurchaseIntent) async {
    let product = intent.product
    guard knownProducts.contains(product.id) else { return }
    await waitUntilReady()
    await process(product: product, intent: intent)
  }

  @available(iOS 16.4, *)
  @MainActor
  private func process(product: Product, intent: PurchaseIntent) async {
    var options: Set<Product.PurchaseOption> = []
    if #available(iOS 18.0, *) {
      if let offer = intent.offer, offer.type == .winBack {
        options.insert(.winBackOffer(offer))
      }
    }
    channel?.invokeMethod("started", arguments: product.id)
    do {
      let result = try await product.purchase(options: options)
      switch result {
      case .success(let verification):
        if case .unverified(_, let error) = verification {
          channel?.invokeMethod("failed", arguments: error.localizedDescription)
        }
      case .userCancelled:
        channel?.invokeMethod("cancelled", arguments: product.id)
      case .pending:
        channel?.invokeMethod("pending", arguments: product.id)
      @unknown default:
        break
      }
    } catch {
      channel?.invokeMethod("failed", arguments: error.localizedDescription)
    }
  }

  @MainActor
  private func waitUntilReady() async {
    if dartReady { return }
    await withCheckedContinuation { continuation in
      readyWaiters.append(continuation)
    }
  }

  @MainActor
  private func markReady() {
    dartReady = true
    let waiters = readyWaiters
    readyWaiters.removeAll()
    for waiter in waiters {
      waiter.resume()
    }
    let payments = pendingPayments
    pendingPayments.removeAll()
    for payment in payments {
      SKPaymentQueue.default().add(payment)
    }
  }

  func paymentQueue(
    _ queue: SKPaymentQueue,
    shouldAddStorePayment payment: SKPayment,
    for product: SKProduct
  ) -> Bool {
    guard knownProducts.contains(payment.productIdentifier) else { return false }
    if dartReady {
      return true
    }
    pendingPayments.append(payment)
    return false
  }

  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    // StoreKit 2 delivers the same transactions to Flutter, which finishes them
    // after the content is granted.
  }
}
