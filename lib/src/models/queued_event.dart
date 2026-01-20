import 'package:ahoy_flutter/src/models/event.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'queued_event.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class QueuedEvent {
  final String id;
  final Event event;
  final String visitToken;
  final String visitorToken;
  final DateTime queuedAt;
  final int retryCount;

  QueuedEvent({
    String? id,
    required this.event,
    required this.visitToken,
    required this.visitorToken,
    DateTime? queuedAt,
    this.retryCount = 0,
  })  : id = id ?? const Uuid().v4(),
        queuedAt = queuedAt ?? DateTime.now().toUtc();

  QueuedEvent copyWith({int? retryCount}) {
    return QueuedEvent(
      id: id,
      event: event,
      visitToken: visitToken,
      visitorToken: visitorToken,
      queuedAt: queuedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  factory QueuedEvent.fromJson(Map<String, dynamic> json) =>
      _$QueuedEventFromJson(json);

  Map<String, dynamic> toJson() => _$QueuedEventToJson(this);
}
