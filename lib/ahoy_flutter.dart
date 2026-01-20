library ahoy_flutter;

export 'src/exceptions/ahoy_error.dart';
export 'src/models/batch_config.dart';
export 'src/models/configuration.dart';
export 'src/models/event.dart';
export 'src/managers/event_queue.dart';
export 'src/managers/event_storage.dart';
export 'src/models/queued_event.dart';
export 'src/network/request_interceptor.dart';
export 'src/managers/token_manager.dart';
export 'src/models/visit.dart';
export 'src/models/visit_change.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ahoy_flutter/src/exceptions/ahoy_error.dart';
import 'package:ahoy_flutter/src/models/configuration.dart';
import 'package:ahoy_flutter/src/models/event.dart';
import 'package:ahoy_flutter/src/managers/event_queue.dart';
import 'package:ahoy_flutter/src/managers/event_storage.dart';
import 'package:ahoy_flutter/src/utils/publisher_ahoy.dart';
import 'package:ahoy_flutter/src/models/queued_event.dart';
import 'package:ahoy_flutter/src/network/request_interceptor.dart';
import 'package:ahoy_flutter/src/managers/token_manager.dart';
import 'package:ahoy_flutter/src/models/visit.dart';
import 'package:ahoy_flutter/src/models/visit_change.dart';

import 'package:http/http.dart';

class Ahoy {
  Visit? _currentVisit;
  final Map<String, String> headers;
  final List<RequestInterceptor> requestInterceptors;
  Timer? _visitExpirationTimer;
  Timer? _flushTimer;
  late final EventQueue _eventQueue;
  bool _isInitialized = false;

  final _visitController = StreamController<VisitChange>.broadcast();

  Stream<VisitChange> get visitStream => _visitController.stream;

  Visit? get currentVisit => _currentVisit;

  Configuration configuration;

  AhoyTokenManager storage;

  Set<StreamSubscription> cancellables = {};

  int get pendingEventCount => _eventQueue.length;

  Ahoy({
    required this.configuration,
    this.headers = const {},
    this.requestInterceptors = const [],
    AhoyTokenManager? tokenStorage,
    EventStorage? eventStorage,
  }) : storage = tokenStorage ??
            TokenManager(expiryPeriod: configuration.visitDuration) {
    _eventQueue = EventQueue(storage: eventStorage);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _eventQueue.loadFromStorage();
    _startFlushTimer();
    _isInitialized = true;
    log(
      'Ahoy initialized with ${_eventQueue.length} pending events',
      name: 'Ahoy',
    );
  }

  Future<Visit> trackVisit({
    String? visitorToken,
    String? utmSource,
    String? utmMedium,
    String? utmTerm,
    String? utmCampaign,
    String? landingPage,
    Map<String, dynamic>? additionalParams,
    bool resetVisit = false,
  }) async {
    if (resetVisit) {
      await storage.resetVisitToken();
    }
    final visit = Visit(
      visitorToken: visitorToken ?? await storage.visitorToken,
      visitToken: await storage.visitToken,
      additionalParams: additionalParams,
    );
    log('Visit tracking started: ${visit.toJson()}', name: 'Ahoy');

    final params = {
      'visit_token': visit.visitToken,
      'visitor_token': visit.visitorToken,
      'user_id': visit.userId,
      'user_agent': configuration.userAgent,
      'app_version': configuration.environment.appVersion,
      'os': configuration.environment.os,
      'os_version': configuration.environment.osVersion,
      'platform': configuration.environment.platform,
      'device_type': configuration.environment.deviceType,
      'landing_page': landingPage,
      'utm_source': utmSource,
      'utm_medium': utmMedium,
      'utm_term': utmTerm,
      'utm_campaign': utmCampaign,
      'started_at': '${DateTime.now().toUtc().toString().split('.')[0]} +0000',
    };

    final response = await _dataTaskPublisher(
      path: configuration.visitsPath,
      body: json.encode(params),
    );

    if (response.statusCode == 200) {
      final previousVisit = _currentVisit;
      _currentVisit = visit;
      _startVisitExpirationTimer();

      if (previousVisit?.visitToken != visit.visitToken) {
        _visitController.add(
          VisitChange(
            visit: visit,
            reason: resetVisit
                ? VisitChangeReason.reset
                : previousVisit != null
                    ? VisitChangeReason.expired
                    : VisitChangeReason.initial,
          ),
        );
      }
      log('Visit tracked: ${currentVisit?.toJson()}', name: 'Ahoy');
      return currentVisit!;
    } else if (response.statusCode == 422) {
      log('Error: Visit not tracked', name: 'Ahoy');
      throw MismatchingVisitError();
    } else {
      log('Error: Visit not tracked', name: 'Ahoy');
      log('Response: ${response.body}', name: 'Ahoy');
      throw UnacceptableResponseError(
        code: response.statusCode,
        data: response.body,
      );
    }
  }

  Future<void> track(List<Event> events) async {
    if (currentVisit == null) {
      log('Error: No Visit Found', name: 'Ahoy');
      throw NoVisitError();
    }

    if (!configuration.batchConfig.enabled) {
      return _sendEventsImmediately(events);
    }

    for (final event in events) {
      await _eventQueue.enqueue(
        event,
        visitToken: currentVisit!.visitToken,
        visitorToken: currentVisit!.visitorToken,
      );
    }

    log(
      'Queued ${events.length} events. Total pending: ${_eventQueue.length}',
      name: 'Ahoy',
    );

    if (_eventQueue.length >= configuration.batchConfig.maxBatchSize) {
      await flush();
    }
  }

  void trackSingle(String eventName, {Map<String, dynamic>? properties}) {
    track([
      Event(
        name: eventName,
        properties: properties ?? {},
        platform: configuration.environment.platform,
      ),
    ]);
  }

  Future<void> flush() async {
    if (_eventQueue.isEmpty) {
      log('No events to flush', name: 'Ahoy');
      return;
    }

    final events = _eventQueue.pendingEvents.toList();
    log('Flushing ${events.length} events', name: 'Ahoy');

    final groupedByVisit = <String, List<QueuedEvent>>{};
    for (final event in events) {
      final key = '${event.visitorToken}:${event.visitToken}';
      groupedByVisit.putIfAbsent(key, () => []).add(event);
    }

    final successfulIds = <String>[];
    final failedEvents = <QueuedEvent>[];

    for (final entry in groupedByVisit.entries) {
      final batchEvents = entry.value;
      final firstEvent = batchEvents.first;

      try {
        final bulkEvent = {
          'visit_token': firstEvent.visitToken,
          'visitor_token': firstEvent.visitorToken,
          'events': batchEvents.map((e) => e.event.toJson()).toList(),
        };

        final response = await _dataTaskPublisher(
          path: configuration.eventsPath,
          body: jsonEncode(bulkEvent),
        );

        if (response.statusCode == 200) {
          successfulIds.addAll(batchEvents.map((e) => e.id));
          log(
            'Batch sent successfully: ${batchEvents.length} events',
            name: 'Ahoy',
          );
        } else {
          failedEvents.addAll(batchEvents);
          log('Batch failed with status ${response.statusCode}', name: 'Ahoy');
        }
      } catch (e) {
        failedEvents.addAll(batchEvents);
        log('Batch failed with error: $e', name: 'Ahoy');
      }
    }

    if (successfulIds.isNotEmpty) {
      await _eventQueue.removeEvents(successfulIds);
    }

    for (final event in failedEvents) {
      final newRetryCount = event.retryCount + 1;
      if (newRetryCount >= configuration.batchConfig.maxRetries) {
        await _eventQueue.removeEvents([event.id]);
        log('Event ${event.id} exceeded max retries, discarding', name: 'Ahoy');
      } else {
        await _eventQueue.updateRetryCount(event.id, newRetryCount);
      }
    }
  }

  void onAppLifecycleStateChange(String state) {
    if ((state == 'paused' || state == 'detached') &&
        configuration.batchConfig.flushOnBackground) {
      flush();
    }
  }

  Future<void> authenticate(String userId) async {
    if (currentVisit == null) {
      log('Error: No Visit Found', name: 'Ahoy');
      throw NoVisitError();
    }

    final params = {
      'visit_token': currentVisit!.visitToken,
      'user_id': userId,
    };

    final response = await _dataTaskPublisher(
      path: configuration.authenticationPath,
      body: jsonEncode(params),
    );
    if (response.statusCode == 200) {
      _currentVisit = _currentVisit?.copyWith(userId: userId);
      log('Visit authenticated: $userId', name: 'Ahoy');
    } else {
      log('Error: Visit not authenticated', name: 'Ahoy');
      log('Response: ${response.body}', name: 'Ahoy');
      throw UnacceptableResponseError(
        code: response.statusCode,
        data: response.body,
      );
    }
  }

  Future<void> _sendEventsImmediately(List<Event> events) async {
    final bulkEvent = {
      'visit_token': currentVisit!.visitToken,
      'visitor_token': currentVisit!.visitorToken,
      'events': events.map((e) => e.toJson()).toList(),
    };

    final response = await _dataTaskPublisher(
      path: configuration.eventsPath,
      body: jsonEncode(bulkEvent),
    );
    if (response.statusCode == 200) {
      log('Bulk Event tracked: $bulkEvent', name: 'Ahoy');
    }
    if (response.statusCode != 200) {
      throw UnacceptableResponseError(
        code: response.statusCode,
        data: response.body,
      );
    }
  }

  Future<Response> _dataTaskPublisher<Body>({
    required String path,
    String? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = Uri(
      scheme: configuration.scheme,
      host: configuration.baseUrl,
      port: configuration.port,
      path: '${configuration.ahoyPath}/$path',
      queryParameters: queryParameters,
    );

    final request = Request('POST', uri);
    if (body != null) {
      request.body = body;
    }
    request.headers['User-Agent'] = configuration.userAgent;
    request.headers['Content-Type'] = 'application/json';

    if (headers != null) {
      request.headers.addAll(headers);
    }
    for (final interceptor in requestInterceptors) {
      interceptor.interceptRequest(request);
    }

    final handledRequest = await configuration.urlRequestHandler(request);
    final response = await Response.fromStream(handledRequest);
    validateResponse(response);
    return response;
  }

  Visit? get visit => currentVisit;

  void _startVisitExpirationTimer() {
    _visitExpirationTimer?.cancel();
    _visitExpirationTimer = Timer(configuration.visitDuration, () async {
      if (currentVisit != null) {
        log('Visit expired, creating new visit', name: 'Ahoy');
        await trackVisit(visitorToken: currentVisit!.visitorToken);
      }
    });
  }

  void _startFlushTimer() {
    if (!configuration.batchConfig.enabled) return;
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(configuration.batchConfig.flushInterval, (_) {
      flush();
    });
  }

  void dispose() {
    _visitExpirationTimer?.cancel();
    _flushTimer?.cancel();
    _visitController.close();
    for (final subscription in cancellables) {
      subscription.cancel();
    }
  }
}
