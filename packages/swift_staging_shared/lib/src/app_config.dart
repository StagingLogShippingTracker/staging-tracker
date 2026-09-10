class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gdrpdiwykmnybmkadlrv.supabase.co',
  );

  /// Public anon key only — never put service-role or Make webhook secrets here.
  ///
  /// This is the project's modern `sb_publishable_...` key, not the legacy
  /// anon JWT. Both authenticate as the anon role for Postgrest/Storage/
  /// Realtime, but Supabase Edge Functions on this project now read the
  /// *current* project key back out of `Deno.env.get('SUPABASE_ANON_KEY')`
  /// — which is this publishable key, not the old JWT — and functions like
  /// `watch-pair` reject a request whose `apikey` header doesn't match it
  /// exactly. Sending the legacy JWT here (as this app did before) produced
  /// a "Missing or invalid apikey" 401 from every Edge Function call,
  /// including Pair Watch, even though Postgrest calls worked fine either
  /// way. Keep this in sync with the project's current key if it ever
  /// rotates again (Supabase dashboard → Settings → API, or the `get_
  /// publishable_keys` MCP tool).
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_nge-ONSQVLDmNzUH2gSmqQ_oCLI4lP1',
  );

  static const freightPhotosBucket = 'freight-photos';
  static const warehouseCc = 'warehouse1@swiftsupply.ca';
  static const publicWebsiteUrl = 'https://www.swiftsupply.ca';

  /// Public GitHub Releases feed for in-app Update downloads (Win/Android/Wear).
  static const githubReleasesPage =
      'https://github.com/StagingLogShippingTracker/staging-tracker/releases';
  static const githubLatestReleaseApi =
      'https://api.github.com/repos/StagingLogShippingTracker/staging-tracker/releases/latest';

  static String publicPhotoUrl(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$supabaseUrl/storage/v1/object/public/$freightPhotosBucket/$clean';
  }
}
