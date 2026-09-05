import 'package:flutter/material.dart';

/// Stable keys for [PopupGate.exclusive] — one open instance per key.
abstract final class PopupKeys {
  static const stagingForm = 'staging_form';
  static const quickShip = 'quick_ship';
  static const ship = 'ship';
  static const returnToStock = 'return_to_stock';
  static const split = 'split';
  static const consolidate = 'consolidate';
  static const orderHistory = 'order_history';
  static const changelog = 'changelog';
  static const shippedEdit = 'shipped_edit';
  static const locationSelector = 'location_selector';
  static const locationMap = 'location_map';
  static const locationAdvisory = 'location_advisory';
  static const photos = 'photos';
  static const documentScanner = 'document_scanner';
  static const confirm = 'confirm';
  static const soAdvisory = 'so_advisory';
  static const statDetail = 'stat_detail';
  static const feedback = 'feedback';
  static const whatsNew = 'whats_new';
  static const howToUse = 'how_to_use';
  static const updatePrompt = 'update_prompt';
  static const verification = 'verification';
}

/// Prevents **duplicate** opens of the same prompt (rapid clicks / hotkeys).
///
/// Intentional multi-step flows still work: different [PopupKeys] may stack
/// (e.g. staging form → location picker → advisory), and sequential opens after
/// a prior Future completes are allowed. Only a second open of the **same**
/// key while the first is still showing is ignored.
class PopupGate {
  PopupGate._();

  static final Set<Object> _held = <Object>{};

  /// True while any exclusively gated popup is open.
  static bool get isOpen => _held.isNotEmpty;

  static bool isHeld(Object key) => _held.contains(key);

  /// Runs [show] unless [key] is already open. Holds the key until the Future
  /// completes (dialog dismissed).
  static Future<T?> exclusive<T>(
    Object key,
    Future<T?> Function() show,
  ) async {
    if (_held.contains(key)) return null;
    _held.add(key);
    try {
      return await show();
    } finally {
      _held.remove(key);
    }
  }

  /// Whether the navigator's top route is already a modal popup.
  static bool topIsModal(BuildContext context) {
    if (!context.mounted) return false;
    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      Route<dynamic>? top;
      navigator.popUntil((route) {
        top = route;
        return true;
      });
      return top is PopupRoute;
    } catch (_) {
      return false;
    }
  }
}
