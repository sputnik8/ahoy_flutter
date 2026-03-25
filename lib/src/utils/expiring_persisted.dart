import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ExpiringPersistedUuid {
  final String key;
  final Duration? expiryPeriod;

  static final Map<String, Completer<String>> _pendingRequests = {};
  static final Map<String, _CachedValue> _cache = {};

  ExpiringPersistedUuid({required this.key, this.expiryPeriod});

  Future<String> get value async {
    final cached = _cache[key];
    if (cached != null && !_isExpired(cached.storageDate)) {
      return cached.value;
    }

    if (_pendingRequests.containsKey(key)) {
      return _pendingRequests[key]!.future;
    }

    final completer = Completer<String>();
    _pendingRequests[key] = completer;

    try {
      final result = await _loadOrCreate();
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingRequests.remove(key);
    }
  }

  bool _isExpired(DateTime storageDate) {
    if (expiryPeriod == null) return false;
    return DateTime.now().toUtc().isAfter(storageDate.add(expiryPeriod!));
  }

  Future<String> _loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    final currDate = DateTime.now().toUtc();

    if (data == null) {
      return await _createAndStore(prefs, currDate);
    }

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final storageDate = DateTime.parse(json['storage_date'] as String);
      final storedValue = json['value'] as String;

      if (_isExpired(storageDate)) {
        return await _createAndStore(prefs, currDate);
      }

      _cache[key] = _CachedValue(value: storedValue, storageDate: storageDate);
      return storedValue;
    } catch (e) {
      return await _createAndStore(prefs, currDate);
    }
  }

  Future<String> _createAndStore(
    SharedPreferences prefs,
    DateTime currDate,
  ) async {
    final newValue = const Uuid().v4();
    final container = {
      'storage_date': currDate.toIso8601String(),
      'value': newValue,
    };
    await prefs.setString(key, jsonEncode(container));
    _cache[key] = _CachedValue(value: newValue, storageDate: currDate);
    return newValue;
  }

  static void clearCache() {
    _cache.clear();
    _pendingRequests.clear();
  }
}

class _CachedValue {
  final String value;
  final DateTime storageDate;

  _CachedValue({required this.value, required this.storageDate});
}
