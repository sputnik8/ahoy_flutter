import 'package:ahoy_flutter/src/utils/expiring_persisted.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const ahoyVisitTokenKey = 'ahoy_visit_token';

sealed class AhoyTokenManager {
  Future<String> get visitToken;
  Future<String> get visitorToken;
  Future<void> resetVisitToken();
  const AhoyTokenManager();
}

class TokenManager extends AhoyTokenManager {
  final Duration expiryPeriod;
  const TokenManager({this.expiryPeriod = const Duration(minutes: 30)});

  @override
  Future<String> get visitToken async {
    return await ExpiringPersistedUuid(
      key: ahoyVisitTokenKey,
      expiryPeriod: expiryPeriod,
    ).value;
  }

  @override
  Future<String> get visitorToken async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('ahoy_visitor_token');
    if (data == null) {
      final visitorToken = const Uuid().v4();
      await prefs.setString('ahoy_visitor_token', visitorToken);
      return visitorToken;
    }

    return data;
  }

  @override
  Future<void> resetVisitToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ahoyVisitTokenKey);
    ExpiringPersistedUuid.clearCacheForKey(ahoyVisitTokenKey);
  }
}
