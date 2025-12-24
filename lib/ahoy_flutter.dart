library ahoy_flutter;

export 'src/exceptions/ahoy_error.dart';
export 'src/models/configuration.dart';
export 'src/models/event.dart';
export 'src/models/visit.dart';
export 'src/models/visit_change.dart';
export 'src/network/ahoy_http_client.dart';
export 'src/network/request_interceptor.dart';
export 'src/managers/token_manager.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ahoy_flutter/src/dtos/visit_request_input.dart';
import 'package:ahoy_flutter/src/exceptions/ahoy_error.dart';
import 'package:ahoy_flutter/src/models/configuration.dart';
import 'package:ahoy_flutter/src/models/event.dart';
import 'package:ahoy_flutter/src/models/visit.dart';
import 'package:ahoy_flutter/src/models/visit_change.dart';
import 'package:ahoy_flutter/src/network/ahoy_http_client.dart';
import 'package:ahoy_flutter/src/network/request_interceptor.dart';
import 'package:ahoy_flutter/src/network/response_validator.dart';
import 'package:ahoy_flutter/src/managers/token_manager.dart';
import 'package:http/http.dart';

/// The main class of the Ahoy library. It is used to track visits and events
/// to a server.
class Ahoy {
  Visit? _currentVisit;
  Timer? _visitExpirationTimer;

  final _visitController = StreamController<VisitChange>.broadcast();

  /// Stream of visit changes. Emits whenever a visit is created or renewed.
  Stream<VisitChange> get visitStream => _visitController.stream;

  Visit? get currentVisit => _currentVisit;

  /// The configuration object for the Ahoy instance. It contains the base URL
  /// of the server, the paths for the visits and events endpoints, and the
  /// environment information.
  final Configuration configuration;

  /// The token manager used to store and retrieve the visitor and visit tokens
  /// from the device's storage. By default, it uses the [TokenManager] class
  /// with the visitDuration from the configuration.
  /// You can provide your own implementation by extending the [AhoyTokenManager]
  final AhoyTokenManager storage;

  /// The HTTP client used to make requests to the Ahoy server.
  /// Can be injected for testing purposes.
  final AhoyHttpClient _httpClient;

  Ahoy({
    required this.configuration,
    Map<String, String> headers = const {},
    List<RequestInterceptor> requestInterceptors = const [],
    AhoyTokenManager? tokenStorage,
    AhoyHttpClient? httpClient,
  })  : storage = tokenStorage ??
            TokenManager(
              expiryPeriod: configuration.visitDuration,
            ),
        _httpClient = httpClient ??
            AhoyHttpClient(
              configuration: configuration,
              headers: headers,
              interceptors: requestInterceptors,
            );

  /// Track a visit to the server and return a [Visit] object
  /// with the visitor and visit tokens.
  /// Optionally, you can pass additional parameters to be sent to the server.
  Future<Visit> trackVisit({
    /// [Optional] Custom visitor token to use for the visit.
    /// If not provided, a new one will be generated.
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

    Response response;
    try {
      response = validateResponse(
        await _httpClient.post(
          path: configuration.visitsPath,
          body: json.encode(params),
        ),
      );
    } on UnacceptableResponseError catch (e) {
      if (e.code == 422) {
        log('Error: Visit not tracked', name: 'Ahoy');
        throw MismatchingVisitError();
      }
      log('Error: Visit not tracked', name: 'Ahoy');
      log('Response: ${e.data}', name: 'Ahoy');
      rethrow;
    }

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
  }

  /// Track a list of events to the server. The events will be associated
  /// with the current visit. If no visit is tracked, a [NoVisitError] will be thrown.
  /// Optionally, you can pass additional parameters to be sent to the server.
  Future<void> track(List<Event> events) async {
    if (currentVisit == null) {
      log('Error: No Visit Found', name: 'Ahoy');

      throw NoVisitError();
    }
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

  /// Track a single event to the server. The event will be associated
  /// with the current visit. If no visit is tracked, a [NoVisitError] will be thrown.
  /// Optionally, you can pass additional parameters to be sent to the server.
  Future<void> trackSingle(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    await track(
      [
        Event(
          name: eventName,
          properties: properties ?? {},
          platform: configuration.environment.platform,
        ),
      ],
    );
  }

  /// Authenticate the current visit with a user ID.
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

  void dispose() {
    _visitExpirationTimer?.cancel();
    _visitController.close();
  }
}
