import 'dart:convert';
import 'package:ahoy_flutter/src/models/queued_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class EventStorage {
  Future<List<QueuedEvent>> loadEvents();
  Future<void> saveEvents(List<QueuedEvent> events);
  Future<void> removeEvents(List<String> eventIds);
  Future<void> clear();
}

class SharedPreferencesEventStorage implements EventStorage {
  static const String _key = 'ahoy_queued_events';

  @override
  Future<List<QueuedEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];

    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => QueuedEvent.fromJson(e)).toList();
  }

  @override
  Future<void> saveEvents(List<QueuedEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = events.map((e) => e.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  @override
  Future<void> removeEvents(List<String> eventIds) async {
    final events = await loadEvents();
    final filtered = events.where((e) => !eventIds.contains(e.id)).toList();
    await saveEvents(filtered);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
