import '../save/save_data.dart';
import '../../game/levels/progression.dart';

const hintProductCredits = <String, int>{
  'revolt_cabino.hints_5': 5,
  'revolt_cabino.hints_15': 15,
  'revolt_cabino.hints_40': 40,
};

final storeProductIds = <String>{
  forbiddenEntitlementId,
  ...hintProductCredits.keys,
};

SaveData grantProduct(
  SaveData data, {
  required String productId,
  required String transactionId,
  required bool restored,
}) {
  if (transactionId.isEmpty || data.processedTransactionIds.contains(transactionId)) {
    return data;
  }
  final credits = hintProductCredits[productId];
  final permanent = productId == forbiddenEntitlementId;
  if (credits == null && !permanent) return data;
  if (restored && credits != null) return data;
  final processed = {...data.processedTransactionIds, transactionId};
  if (permanent) {
    return data.copyWith(
      permanentEntitlements: {...data.permanentEntitlements, productId},
      processedTransactionIds: processed,
    );
  }
  return data.copyWith(
    hintBalance: data.hintBalance + credits!,
    processedTransactionIds: processed,
  );
}
