import 'package:ahoy_flutter/ahoy_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'ahoy_flutter_test.mocks.dart';

class FakeTokenManager extends TokenManager {
  final String _visitorToken;
  final String _visitToken;

  FakeTokenManager({
    String visitorToken = 'visitorToken',
    String visitToken = 'visitToken',
  })  : _visitorToken = visitorToken,
        _visitToken = visitToken;

  @override
  Future<String> get visitorToken async => _visitorToken;

  @override
  Future<String> get visitToken async => _visitToken;

  @override
  Future<void> resetVisitToken() async {}
}

@GenerateMocks([AhoyHttpClient])
void main() {
  late Ahoy ahoy;
  late FakeTokenManager fakeTokenManager;
  late MockAhoyHttpClient mockHttpClient;
  late Configuration configuration;

  setUp(() {
    fakeTokenManager = FakeTokenManager();
    mockHttpClient = MockAhoyHttpClient();
    configuration = Configuration(
      baseUrl: 'example.com',
      ahoyPath: 'ahoy',
      visitsPath: 'visits',
      eventsPath: 'events',
      environment: ApplicationEnvironment(
        deviceType: 'Mobile',
        platform: 'flutter',
        appVersion: '1.0.0',
        os: 'iOS',
        osVersion: '1.0.0',
      ),
    );
    ahoy = Ahoy(
      configuration: configuration,
      tokenStorage: fakeTokenManager,
      httpClient: mockHttpClient,
    );
  });

  group('Ahoy', () {
    test('trackVisit should return a Visit object with server response',
        () async {
      when(
        mockHttpClient.post(
          path: anyNamed('path'),
          body: anyNamed('body'),
          additionalHeaders: anyNamed('additionalHeaders'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"visitor_token": "visitorToken", "visit_token": "visitToken", "visit_id": "123", "visitor_id": "456"}',
          200,
        ),
      );

      final visit = await ahoy.trackVisit();

      expect(visit.visitorToken, 'visitorToken');
      expect(visit.visitToken, 'visitToken');
      expect(visit.visitId, '123');
      expect(visit.visitorId, '456');
    });

    test('track should throw NoVisitError if no visit is tracked', () async {
      expect(() => ahoy.track([]), throwsA(isA<NoVisitError>()));
    });

    test('trackSingle should track a single event', () async {
      when(
        mockHttpClient.post(
          path: anyNamed('path'),
          body: anyNamed('body'),
          additionalHeaders: anyNamed('additionalHeaders'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"visitor_token": "visitorToken", "visit_token": "visitToken"}',
          200,
        ),
      );

      await ahoy.trackVisit();

      await ahoy.trackSingle('eventName', properties: {'key': 'value'});

      verify(
        mockHttpClient.post(
          path: 'events',
          body: anyNamed('body'),
          additionalHeaders: anyNamed('additionalHeaders'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).called(1);
    });

    test('authenticate should update the currentVisit with the provided userId',
        () async {
      when(
        mockHttpClient.post(
          path: anyNamed('path'),
          body: anyNamed('body'),
          additionalHeaders: anyNamed('additionalHeaders'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"visitor_token": "visitorToken", "visit_token": "visitToken"}',
          200,
        ),
      );

      await ahoy.trackVisit();

      await ahoy.authenticate('userId');

      expect(ahoy.currentVisit?.userId, 'userId');
    });

    test('visitStream emits VisitChange on new visit', () async {
      when(
        mockHttpClient.post(
          path: anyNamed('path'),
          body: anyNamed('body'),
          additionalHeaders: anyNamed('additionalHeaders'),
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"visitor_token": "visitorToken", "visit_token": "visitToken"}',
          200,
        ),
      );

      expectLater(
        ahoy.visitStream,
        emits(
          isA<VisitChange>()
              .having((c) => c.reason, 'reason', VisitChangeReason.initial),
        ),
      );

      await ahoy.trackVisit();
    });
  });
}
