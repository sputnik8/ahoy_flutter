import 'package:ahoy_flutter/src/visit.dart';

enum VisitChangeReason {
  /// Initial visit creation
  initial,

  /// Visit was renewed due to expiration
  expired,

  /// Visit was manually reset
  reset,
}

class VisitChange {
  final Visit visit;
  final VisitChangeReason reason;

  const VisitChange({
    required this.visit,
    required this.reason,
  });
}
