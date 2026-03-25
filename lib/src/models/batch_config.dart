class BatchConfig {
  final bool enabled;
  final int maxBatchSize;
  final Duration flushInterval;
  final int maxRetries;

  const BatchConfig({
    this.enabled = true,
    this.maxBatchSize = 20,
    this.flushInterval = const Duration(seconds: 30),
    this.maxRetries = 3,
  });

  static const BatchConfig disabled = BatchConfig(enabled: false);
}
