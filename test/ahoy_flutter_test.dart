import 'dart:convert';
import 'package:ahoy_flutter/ahoy_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

import 'ahoy_flutter_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<TokenManager>(),
  MockSpec<http.Client>(),
  MockSpec<EventStorage>(),
])
void main() {
  late Ahoy ahoy;
  late MockTokenManager mockTokenManager;
  late MockClient mockHttpClient;
  late MockEventStorage mockEventStorage;

  setUp(() {
    mockTokenManager = MockTokenManager();
    mockHttpClient = MockClient();
    mockEventStorage = MockEventStorage();

    final config = Configuration(
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
      configuration: config,
      tokenStorage: mockTokenManager,
      httpClient: AhoyHttpClient(
        configuration: config,
        client: mockHttpClient,
      ),
      eventStorage: mockEventStorage,
    );
  });

  group('Ahoy', () {
    test('trackVisit should return a Visit object', () async {
      when(mockTokenManager.visitorToken)
          .thenAnswer((_) async => 'visitorToken');
      when(mockTokenManager.visitToken).thenAnswer((_) async => 'visitToken');

      when(
        mockHttpClient.send(any),
      ).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(
            const JsonEncoder().convert({
              "visitor_token": "visitorToken",
              "visit_token": "visitToken",
            }).codeUnits,
          ),
          200,
        ),
      );

      final visit = await ahoy.trackVisit();
      expect(visit.visitorToken, 'visitorToken');
      expect(visit.visitToken, 'visitToken');
    });

    test('track should throw NoVisitError if no visit is tracked', () async {
      expect(() => ahoy.track([]), throwsA(isA<NoVisitError>()));
    });

    test('trackSingle should track a single event', () async {
      final noBatchConfig = Configuration(
        baseUrl: 'example.com',
        ahoyPath: 'ahoy',
        visitsPath: 'visits',
        eventsPath: 'events',
        batchConfig: const BatchConfig(enabled: false),
        environment: ApplicationEnvironment(
          deviceType: 'Mobile',
          platform: 'flutter',
          appVersion: '1.0.0',
          os: 'iOS',
          osVersion: '1.0.0',
        ),
      );

      ahoy = Ahoy(
        configuration: noBatchConfig,
        tokenStorage: mockTokenManager,
        httpClient: AhoyHttpClient(
          configuration: noBatchConfig,
          client: mockHttpClient,
        ),
        eventStorage: mockEventStorage,
      );

      when(mockTokenManager.visitorToken)
          .thenAnswer((_) async => 'visitorToken');
      when(mockTokenManager.visitToken).thenAnswer((_) async => 'visitToken');

      when(
        mockHttpClient.send(any),
      ).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(
            const JsonEncoder().convert({
              "visitor_token": "visitorToken",
              "visit_token": "visitToken",
            }).codeUnits,
          ),
          200,
        ),
      );

      await ahoy.trackVisit();

      await ahoy.trackSingle('eventName');

      verify(mockHttpClient.send(any)).called(2);
    });

    test('authenticate should update the currentVisit with the provided userId',
        () async {
      when(mockTokenManager.visitorToken)
          .thenAnswer((_) async => 'visitorToken');
      when(mockTokenManager.visitToken).thenAnswer((_) async => 'visitToken');

      when(
        mockHttpClient.send(any),
      ).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(
            const JsonEncoder().convert({}).codeUnits,
          ),
          200,
        ),
      );

      await ahoy.trackVisit();

      await ahoy.authenticate('userId');

      expect(ahoy.currentVisit?.userId, 'userId');
    });
  });
}
