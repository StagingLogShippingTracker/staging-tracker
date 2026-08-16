/// Uppercases the full PM notification email subject line.
String capitalizeEmailSubject(String subject) {
  if (subject.trim().isEmpty) return subject;
  return subject.toUpperCase();
}
