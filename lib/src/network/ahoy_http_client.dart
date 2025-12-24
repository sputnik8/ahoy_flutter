import 'package:ahoy_flutter/src/models/configuration.dart';
import 'package:ahoy_flutter/src/network/request_interceptor.dart';
import 'package:http/http.dart';

/// A dedicated HTTP client for Ahoy API requests.
///
/// Encapsulates URI construction, header management, request interception,
/// and response handling.
class AhoyHttpClient {
  final Configuration configuration;
  final Map<String, String> headers;
  final List<RequestInterceptor> interceptors;

  AhoyHttpClient({
    required this.configuration,
    this.headers = const {},
    this.interceptors = const [],
  });

  /// Sends a POST request to the specified path.
  ///
  /// The [path] is appended to the configured ahoyPath.
  /// Optional [body] is sent as JSON.
  /// Optional [queryParameters] are appended to the URL.
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

    // Set default headers
    request.headers['User-Agent'] = configuration.userAgent;
    request.headers['Content-Type'] = 'application/json';

    // Add instance headers
    request.headers.addAll(headers);

    // Add request-specific headers
    if (additionalHeaders != null) {
      request.headers.addAll(additionalHeaders);
    }

    // Apply interceptors
    for (final interceptor in interceptors) {
      interceptor.interceptRequest(request);
    }

    // Execute request
    final streamedResponse = await configuration.urlRequestHandler(request);
    return Response.fromStream(streamedResponse);
  }
}
