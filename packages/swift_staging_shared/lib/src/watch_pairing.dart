import 'package:supabase_flutter/supabase_flutter.dart';

class WatchPairCreateResult {
  const WatchPairCreateResult({
    required this.code,
    required this.expiresAt,
  });

  final String code;
  final DateTime expiresAt;
}

class WatchPairRedeemResult {
  const WatchPairRedeemResult({
    required this.paired,
    this.sessionSet = false,
  });

  final bool paired;
  /// True when a Supabase Auth session was established (legacy user-bound codes).
  final bool sessionSet;
}

class WatchPairingClient {
  WatchPairingClient(this._client);
  final SupabaseClient _client;

  /// Phone/Windows: create a short-lived pairing code (anon floor OK).
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

  /// Wear: redeem code. Floor codes mark paired without a user session;
  /// legacy user-bound codes still set a Supabase session when tokens return.
  Future<WatchPairRedeemResult> redeemCode(String code) async {
    final res = await _client.functions.invoke(
      'watch-pair',
      body: {'action': 'redeem', 'code': code.trim()},
    );
    if (res.status >= 400) {
      throw Exception('Pair redeem failed (${res.status}): ${res.data}');
    }
    final data = Map<String, dynamic>.from(res.data as Map);
    final refresh = '${data['refresh_token'] ?? ''}'.trim();
    if (refresh.isNotEmpty) {
      await _client.auth.setSession(refresh);
      return const WatchPairRedeemResult(paired: true, sessionSet: true);
    }
    if (data['paired'] == true) {
      return const WatchPairRedeemResult(paired: true);
    }
    throw Exception('Pair redeem returned no pairing confirmation');
  }
}
