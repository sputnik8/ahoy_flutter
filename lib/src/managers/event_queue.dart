import 'package:ahoy_flutter/src/models/event.dart';
import 'package:ahoy_flutter/src/managers/event_storage.dart';
import 'package:ahoy_flutter/src/models/queued_event.dart';

class EventQueue {
  final EventStorage _storage;
  final List<QueuedEvent> _queue = [];
  bool _isLoaded = false;

  EventQueue({EventStorage? storage})
      : _storage = storage ?? SharedPreferencesEventStorage();

  List<QueuedEvent> get pendingEvents => List.unmodifiable(_queue);

  int get length => _queue.length;

  bool get isEmpty => _queue.isEmpty;

  Future<void> loadFromStorage() async {
    if (_isLoaded) return;
    final events = await _storage.loadEvents();
    _queue.addAll(events);
    _isLoaded = true;
  }

  Future<void> enqueue(
    Event event, {
    required String visitToken,
    required String visitorToken,
  }) async {
    final queuedEvent = QueuedEvent(
      event: event,
      visitToken: visitToken,
      visitorToken: visitorToken,
    );
    _queue.add(queuedEvent);
    await _saveToStorage();
  }

  Future<void> removeEvents(List<String> eventIds) async {
    _queue.removeWhere((e) => eventIds.contains(e.id));
    await _saveToStorage();
  }

  Future<void> updateRetryCount(String eventId, int retryCount) async {
    final index = _queue.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(retryCount: retryCount);
      await _saveToStorage();
    }
  }

  Future<void> clear() async {
    _queue.clear();
    await _storage.clear();
  }

  Future<void> _saveToStorage() async {
    await _storage.saveEvents(_queue);
  }
}
