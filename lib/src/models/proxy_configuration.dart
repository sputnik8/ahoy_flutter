/// Configuration for routing HTTP traffic through a proxy (e.g. Charles Proxy).
class ProxyConfiguration {
  /// The proxy host (e.g. "localhost" or "192.168.1.100").
  final String host;

  /// The proxy port (e.g. 8888 for Charles).
  final int port;

  /// If true, allows connections to proxies with untrusted SSL certificates.
  /// Required for Charles HTTPS proxying. **Do not enable in production.**
  final bool allowBadCertificates;

  const ProxyConfiguration({
    required this.host,
    this.port = 8888,
    this.allowBadCertificates = false,
  });

  @override
  String toString() => 'ProxyConfiguration($host:$port)';
}
