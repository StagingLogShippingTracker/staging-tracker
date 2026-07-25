import 'package:supabase_flutter/supabase_flutter.dart';

class WatchPairCreateResult {
  const WatchPairCreateResult({
    required this.code,
    required this.expiresAt,
  });

  final String code;
  final DateTime expiresAt;
}

class WatchPairingClient {
  WatchPairingClient(this._client);
  final SupabaseClient _client;

  /// Authenticated phone/Windows: create a short-lived pairing code.
  Future<WatchPairCreateResult> createCode() async {
    final res = await _client.functions.invoke(
      'watch-pair',
      body: {'action': 'create'},
    );
    if (res.status >= 400) {
      throw Exception('Pair create failed (${res.status}): ${res.data}');
    }
    final data = Map<String, dynamic>.from(res.data as Map);
    return WatchPairCreateResult(
      code: '${data['code']}',
      expiresAt: DateTime.parse('${data['expires_at']}'),
    );
  }

  /// Wear (anonymous or no session): redeem code for a Supabase session.
  Future<AuthResponse> redeemCode(String code) async {
    final res = await _client.functions.invoke(
      'watch-pair',
      body: {'action': 'redeem', 'code': code.trim()},
    );
    if (res.status >= 400) {
      throw Exception('Pair redeem failed (${res.status}): ${res.data}');
    }
    final data = Map<String, dynamic>.from(res.data as Map);
    final refresh = '${data['refresh_token']}';
    if (refresh.isEmpty) {
      throw Exception('Pair redeem returned no refresh token');
    }
    return _client.auth.setSession(refresh);
  }
}
