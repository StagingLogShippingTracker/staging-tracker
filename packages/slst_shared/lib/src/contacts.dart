import 'models.dart';
import 'repositories.dart';

/// Ensures warehouse ops emails are always present in the contact roster.
List<ContactPerson> withWarehouseContacts(List<ContactPerson> contacts) {
  final extras = [
    ContactPerson(
      name: 'Warehouse 1',
      designation: 'Operations',
      email: 'warehouse1@swiftsupply.ca',
      ext: 'N/A',
      direct: 'N/A',
      mobile: 'N/A',
      branch: 'Nisku',
    ),
    ContactPerson(
      name: 'Warehouse 2',
      designation: 'Operations',
      email: 'warehouse2@swiftsupply.ca',
      ext: 'N/A',
      direct: 'N/A',
      mobile: 'N/A',
      branch: 'Nisku',
    ),
  ];
  final emails = {
    for (final c in contacts) c.email.trim().toLowerCase(),
  };
  final out = [...contacts];
  for (final e in extras) {
    if (!emails.contains(e.email.toLowerCase())) out.add(e);
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

Future<List<ContactPerson>> loadContactsWithWarehouse() async {
  return withWarehouseContacts(await loadBundledContacts());
}
