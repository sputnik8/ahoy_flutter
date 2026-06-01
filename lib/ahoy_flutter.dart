library ahoy_flutter;

export 'src/exceptions/ahoy_error.dart';
export 'src/models/batch_config.dart';
export 'src/models/configuration.dart';
export 'src/models/event.dart';
export 'src/managers/event_queue.dart';
export 'src/managers/event_storage.dart';
export 'src/models/queued_event.dart';
export 'src/network/ahoy_http_client.dart';
export 'src/models/proxy_configuration.dart';
export 'src/network/request_interceptor.dart';
export 'src/managers/token_manager.dart';
export 'src/models/visit.dart';
export 'src/models/visit_change.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:collection/collection.dart';

import 'package:ahoy_flutter/src/dtos/update_attribution_request_input.dart';
import 'package:ahoy_flutter/src/dtos/visit_request_input.dart';
import 'package:ahoy_flutter/src/exceptions/ahoy_error.dart';
import 'package:ahoy_flutter/src/models/configuration.dart';
import 'package:ahoy_flutter/src/models/event.dart';
import 'package:ahoy_flutter/src/models/proxy_configuration.dart';
import 'package:ahoy_flutter/src/managers/event_queue.dart';
import 'package:ahoy_flutter/src/managers/event_storage.dart';
import 'package:ahoy_flutter/src/models/queued_event.dart';
import 'package:ahoy_flutter/src/network/ahoy_http_client.dart';
import 'package:ahoy_flutter/src/network/request_interceptor.dart';
import 'package:ahoy_flutter/src/network/response_validator.dart';
import 'package:ahoy_flutter/src/managers/token_manager.dart';
import 'package:ahoy_flutter/src/models/visit.dart';
import 'package:ahoy_flutter/src/models/visit_change.dart';

class Ahoy {
  Visit? _currentVisit;
  Timer? _visitExpirationTimer;
  Timer? _flushTimer;
  bool _isFlushing = false;
  late final EventQueue _eventQueue;
  bool _isInitialized = false;

  final _visitController = StreamController<VisitChange>.broadcast();

  Stream<VisitChange> get visitStream => _visitController.stream;

  Visit? get currentVisit => _currentVisit;

  final Configuration configuration;

  final AhoyTokenManager storage;

  final AhoyHttpClient _httpClient;

  int get pendingEventCount => _eventQueue.length;

  Ahoy({
    required this.configuration,
    Map<String, String> headers = const {},
    List<RequestInterceptor> requestInterceptors = const [],
    AhoyTokenManager? tokenStorage,
    AhoyHttpClient? httpClient,
    EventStorage? eventStorage,
    ProxyConfiguration? proxyConfiguration,
  })  : storage = tokenStorage ??
            TokenManager(expiryPeriod: configuration.visitDuration),
        _httpClient = httpClient ??
            AhoyHttpClient(
              configuration: configuration,
              headers: headers,
              interceptors: requestInterceptors,
              proxyConfiguration: proxyConfiguration,
            ) {
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

    final params = VisitRequestInput(
      visitToken: visit.visitToken,
      visitorToken: visit.visitorToken,
      userId: visit.userId,
      userAgent: configuration.userAgent,
      appVersion: configuration.environment.appVersion,
      os: configuration.environment.os,
      osVersion: configuration.environment.osVersion,
      platform: configuration.environment.platform,
      deviceType: configuration.environment.deviceType,
      landingPage: landingPage,
      utmSource: utmSource,
      utmMedium: utmMedium,
      utmTerm: utmTerm,
      utmCampaign: utmCampaign,
      startedAt: '${DateTime.now().toUtc().toString().split('.')[0]} +0000',
    ).toJson();

    try {
      final response = validateResponse(
        await _httpClient.post(
          path: configuration.visitsPath,
          body: json.encode(params),
        ),
      );

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final serverVisit = Visit.fromJson(responseData).copyWith(
        additionalParams: additionalParams,
      );

      final previousVisit = _currentVisit;
      _currentVisit = serverVisit;
      _startVisitExpirationTimer();

      if (previousVisit?.visitToken != serverVisit.visitToken) {
        _visitController.add(
          VisitChange(
            visit: serverVisit,
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
    } on UnacceptableResponseError catch (e) {
      if (e.code == 422) {
        log('Error: Visit not tracked', name: 'Ahoy');
        throw MismatchingVisitError();
      }
      log('Error: Visit not tracked', name: 'Ahoy');
      log('Response: ${e.data}', name: 'Ahoy');
      rethrow;
    }
  }

  Future<void> track(List<Event> events, {bool sendImmediately = false}) async {
    if (currentVisit == null) {
      log('Error: No Visit Found', name: 'Ahoy');
      throw NoVisitError();
    }

    if (!configuration.batchConfig.enabled || sendImmediately) {
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

  Future<void> trackSingle(
    String eventName, {
    Map<String, dynamic>? properties,
    bool sendImmediately = false,
  }) async {
    await track(
      [
        Event(
          name: eventName,
          properties: properties ?? {},
          platform: configuration.environment.platform,
        ),
      ],
      sendImmediately: sendImmediately,
    );
  }

  Future<void> flush() async {
    if (_isFlushing) return;
    if (_eventQueue.isEmpty) {
      log('No events to flush', name: 'Ahoy');
      return;
    }

    _isFlushing = true;
    try {
      final events = _eventQueue.pendingEvents.toList();
      log('Flushing ${events.length} events', name: 'Ahoy');

      final groupedByVisit = events.groupListsBy(
        (event) => '${event.visitorToken}:${event.visitToken}',
      );

      final successfulIds = <String>[];
      final failedEvents = <QueuedEvent>[];

      for (final batchEvents in groupedByVisit.values) {
        final sentIds = await _sendBatchForVisit(batchEvents);
        if (sentIds != null) {
          successfulIds.addAll(sentIds);
        } else {
          failedEvents.addAll(batchEvents);
        }
      }

      if (successfulIds.isNotEmpty) {
        await _eventQueue.removeEvents(successfulIds);
      }

      await _handleFailedEvents(failedEvents);
    } finally {
      _isFlushing = false;
    }
  }

  Future<List<String>?> _sendBatchForVisit(
    List<QueuedEvent> batchEvents,
  ) async {
    final firstEvent = batchEvents.first;

    try {
      final bulkEvent = {
        'visit_token': firstEvent.visitToken,
        'visitor_token': firstEvent.visitorToken,
        'events': batchEvents.map((e) => e.event.toJson()).toList(),
      };

      validateResponse(
        await _httpClient.post(
          path: configuration.eventsPath,
          body: jsonEncode(bulkEvent),
        ),
      );

      log(
        'Batch sent successfully: ${batchEvents.length} events',
        name: 'Ahoy',
      );
      return batchEvents.map((e) => e.id).toList();
    } on UnacceptableResponseError catch (e) {
      log('Batch failed with status ${e.code}', name: 'Ahoy');
      return null;
    } catch (e) {
      log('Batch failed with error: $e', name: 'Ahoy');
      return null;
    }
  }

  Future<void> _handleFailedEvents(List<QueuedEvent> failedEvents) async {
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

  Future<Visit> updateVisitAttribution({
    String? landingPage,
    String? utmSource,
    String? utmMedium,
    String? utmTerm,
    String? utmCampaign,
    Map<String, dynamic>? additionalParams,
  }) async {
    if (currentVisit == null) {
      log('Error: No Visit Found', name: 'Ahoy');
      throw NoVisitError();
    }

    final params = UpdateAttributionRequestInput(
      visitToken: currentVisit!.visitToken,
      landingPage: landingPage,
      utmSource: utmSource,
      utmMedium: utmMedium,
      utmTerm: utmTerm,
      utmCampaign: utmCampaign,
      additionalParams: additionalParams,
    ).toJson();

    try {
      final response = validateResponse(
        await _httpClient.post(
          path: configuration.updateAttributionPath,
          body: json.encode(params),
        ),
      );

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final mergedAdditionalParams = {
        ...?currentVisit!.additionalParams,
        ...?additionalParams,
      };
      final updatedVisit = Visit.fromJson(responseData).copyWith(
        additionalParams:
            mergedAdditionalParams.isEmpty ? null : mergedAdditionalParams,
      );

      _currentVisit = updatedVisit;
      log('Visit attribution updated: ${currentVisit?.toJson()}', name: 'Ahoy');
      return currentVisit!;
    } on UnacceptableResponseError catch (e) {
      if (e.code == 422) {
        log('Error: Visit attribution not updated', name: 'Ahoy');
        throw MismatchingVisitError();
      }
      log('Error: Visit attribution not updated', name: 'Ahoy');
      log('Response: ${e.data}', name: 'Ahoy');
      rethrow;
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

    final response = validateResponse(
      await _httpClient.post(
        path: configuration.authenticationPath,
        body: jsonEncode(params),
      ),
    );

    _currentVisit = _currentVisit?.copyWith(userId: userId);
    log('Visit authenticated: $userId', name: 'Ahoy');
    log('Response: ${response.body}', name: 'Ahoy');
  }

  Future<void> _sendEventsImmediately(List<Event> events) async {
    final bulkEvent = {
      'visit_token': currentVisit!.visitToken,
      'visitor_token': currentVisit!.visitorToken,
      'events': events.map((e) => e.toJson()).toList(),
    };

    validateResponse(
      await _httpClient.post(
        path: configuration.eventsPath,
        body: jsonEncode(bulkEvent),
      ),
    );

    log('Bulk Event tracked: $bulkEvent', name: 'Ahoy');
  }

  Visit? get visit => currentVisit;

  void _startVisitExpirationTimer() {
    _visitExpirationTimer?.cancel();
    _visitExpirationTimer = Timer(configuration.visitDuration, () async {
      if (currentVisit != null) {
        try {
          log('Visit expired, creating new visit', name: 'Ahoy');
          await trackVisit(visitorToken: currentVisit!.visitorToken);
        } catch (e, stackTrace) {
          log(
            'Error renewing expired visit: $e',
            name: 'Ahoy',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
    });
  }

  void _startFlushTimer() {
    if (!configuration.batchConfig.enabled) return;
    _flushTimer?.cancel();
    _flushTimer =
        Timer.periodic(configuration.batchConfig.flushInterval, (_) async {
      try {
        await flush();
      } catch (e, stackTrace) {
        log(
          'Error during scheduled flush: $e',
          name: 'Ahoy',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }

  void dispose() {
    _visitExpirationTimer?.cancel();
    _flushTimer?.cancel();
    _visitController.close();
  }
}
