import 'dart:io';

import 'package:ahoy_flutter/src/models/configuration.dart';
import 'package:ahoy_flutter/src/models/proxy_configuration.dart';
import 'package:ahoy_flutter/src/network/request_interceptor.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

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
    ProxyConfiguration? proxyConfiguration,
  }) : _client = client ?? _createClient(proxyConfiguration);

  static Client _createClient(ProxyConfiguration? proxyConfiguration) {
    if (proxyConfiguration == null) return Client();

    final httpClient = HttpClient()
      ..findProxy = (uri) =>
          'PROXY ${proxyConfiguration.host}:${proxyConfiguration.port}';

    if (proxyConfiguration.allowBadCertificates) {
      httpClient.badCertificateCallback = (cert, host, port) => true;
    }

    return IOClient(httpClient);
  }

  Future<Response> post({
    required String path,
    String? body,
    Map<String, String>? additionalHeaders,
    Map<String, dynamic>? queryParameters,
    bool customPath = false,
  }) {
    return _sendRequest(
      method: 'POST',
      path: path,
      body: body,
      additionalHeaders: additionalHeaders,
      queryParameters: queryParameters,
      customPath: customPath,
    );
  }

  Future<Response> patch({
    required String path,
    String? body,
    Map<String, String>? additionalHeaders,
    Map<String, dynamic>? queryParameters,
    bool customPath = false,
  }) {
    return _sendRequest(
      method: 'PATCH',
      path: path,
      body: body,
      additionalHeaders: additionalHeaders,
      queryParameters: queryParameters,
      customPath: customPath,
    );
  }

  Future<Response> _sendRequest({
    required String method,
    required String path,
    String? body,
    Map<String, String>? additionalHeaders,
    Map<String, dynamic>? queryParameters,
    bool customPath = false,
  }) async {
    final uri = Uri(
      scheme: configuration.scheme,
      host: configuration.baseUrl,
      port: configuration.port,
      path: customPath ? path : '${configuration.ahoyPath}/$path',
      queryParameters: queryParameters,
    );

    final request = Request(method, uri);

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
