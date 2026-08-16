/// Shared field validation for staging / ship / notify flows.
class SlstValidation {
  static String? requireNonEmpty(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  static String? requireEmail(String? value, {String label = 'Email'}) {
    final empty = requireNonEmpty(value, label);
    if (empty != null) return empty;
    if (!value!.contains('@') || value.trim().length < 5) {
      return 'Enter a valid $label.';
    }
    return null;
  }

  static void ensureShipFields({
    required String so,
    required String customer,
    required String carrier,
    required String shippedBy,
  }) {
    final errors = [
      requireNonEmpty(so, 'SO'),
      requireNonEmpty(customer, 'Customer'),
      requireNonEmpty(carrier, 'Carrier'),
      requireNonEmpty(shippedBy, 'Shipped by'),
    ].whereType<String>().toList();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.first);
    }
  }

  static void ensureReturnFields({
    required String pickedBy,
    required String returnedBy,
    required String reason,
  }) {
    final errors = [
      requireNonEmpty(pickedBy, 'Picked by'),
      requireNonEmpty(returnedBy, 'Returned by'),
      requireNonEmpty(reason, 'Reason'),
    ].whereType<String>().toList();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.first);
    }
  }

  static void ensurePoNotification({
    required String po,
    required String vendor,
    required String pmEmail,
  }) {
    final errors = [
      requireNonEmpty(po, 'PO'),
      requireNonEmpty(vendor, 'Vendor'),
      requireEmail(pmEmail, label: 'PM email'),
    ].whereType<String>().toList();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.first);
    }
  }

  static void ensureReturnNotification({
    required String so,
    required String customer,
    required String pmEmail,
  }) {
    final errors = [
      requireNonEmpty(so, 'SO'),
      requireNonEmpty(customer, 'Customer'),
      requireEmail(pmEmail, label: 'PM email'),
    ].whereType<String>().toList();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.first);
    }
  }
}
