/// Business-protocol sentinel strings and predicates shared by all clients.
class InventorySentinels {
  static const returnedToStock = 'RETURNED TO STOCK';
  static const consolidated = 'CONSOLIDATED';
  static const binMovementPrefix = 'Bin Movement:';
}

bool isReturnToStockCarrier(String carrier) =>
    carrier.trim().toUpperCase() == InventorySentinels.returnedToStock;

bool isConsolidateCarrier(String carrier) =>
    carrier.trim().toUpperCase() == InventorySentinels.consolidated;

bool isTrueShipmentCarrier(String carrier) {
  final c = carrier.trim().toUpperCase();
  return c != InventorySentinels.returnedToStock &&
      c != InventorySentinels.consolidated;
}

bool isBinMovementAction(String action) =>
    action.trim().startsWith(InventorySentinels.binMovementPrefix);
