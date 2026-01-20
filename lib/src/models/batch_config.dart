class BatchConfig {
  final bool enabled;
  final int maxBatchSize;
  final Duration flushInterval;
  final int maxRetries;
  final bool flushOnBackground;

  const BatchConfig({
    this.enabled = true,
    this.maxBatchSize = 20,
    this.flushInterval = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.flushOnBackground = true,
  });

  static const BatchConfig disabled = BatchConfig(enabled: false);
}
