import 'package:ahoy_flutter/src/models/configuration.dart';
import 'package:ahoy_flutter/src/network/request_interceptor.dart';
import 'package:http/http.dart';

class AhoyHttpClient {
  final Configuration configuration;
  final Map<String, String> headers;
  final List<RequestInterceptor> interceptors;
  final Client _client;

  AhoyHttpClient({
    required this.configuration,
    this.headers = const {},
    this.interceptors = const [],
    Client? client,
  }) : _client = client ?? Client();

  Future<Response> post({
    required String path,
    String? body,
    Map<String, String>? additionalHeaders,
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

    request.headers.addAll(headers);

    if (additionalHeaders != null) {
      request.headers.addAll(additionalHeaders);
    }

    for (final interceptor in interceptors) {
      interceptor.interceptRequest(request);
    }

    final streamedResponse = await _client.send(request);
    return Response.fromStream(streamedResponse);
  }

  void close() {
    _client.close();
  }
}
