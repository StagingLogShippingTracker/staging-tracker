class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gdrpdiwykmnybmkadlrv.supabase.co',
  );

  /// Public anon key only — never put service-role or Make webhook secrets here.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkcnBkaXd5a21ueWJta2FkbHJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1MjMyMTIsImV4cCI6MjA5NjA5OTIxMn0.Z7ih_vQic1GtzCyZmTEV-RWJnmuaNZQDfOV2_Fvan5g',
  );

  static const freightPhotosBucket = 'freight-photos';
  static const warehouseCc = 'warehouse1@swiftsupply.ca';
  static const warehouse2Email = 'warehouse2@swiftsupply.ca';
  static const accessRequestEmail = warehouse2Email;

  static String publicPhotoUrl(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$supabaseUrl/storage/v1/object/public/$freightPhotosBucket/$clean';
  }
}
