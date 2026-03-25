/// Configuration for routing HTTP traffic through a proxy (e.g. Charles Proxy).
class ProxyConfiguration {
  /// The proxy address in "host:port" format (e.g. "localhost:8888").
  final String address;

  /// If true, allows connections to proxies with untrusted SSL certificates.
  /// Required for Charles HTTPS proxying. **Do not enable in production.**
  final bool allowBadCertificates;

  const ProxyConfiguration({
    required this.address,
    this.allowBadCertificates = false,
  });

  String get host => address.split(':').first;

  int get port =>
      address.contains(':') ? int.parse(address.split(':').last) : 8888;

  @override
  String toString() => 'ProxyConfiguration($address)';
}
