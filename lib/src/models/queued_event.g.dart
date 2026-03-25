// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queued_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueuedEvent _$QueuedEventFromJson(Map<String, dynamic> json) => QueuedEvent(
      id: json['id'] as String?,
      event: Event.fromJson(json['event'] as Map<String, dynamic>),
      visitToken: json['visit_token'] as String,
      visitorToken: json['visitor_token'] as String,
      queuedAt: json['queued_at'] == null
          ? null
          : DateTime.parse(json['queued_at'] as String),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$QueuedEventToJson(QueuedEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'event': instance.event,
      'visit_token': instance.visitToken,
      'visitor_token': instance.visitorToken,
      'queued_at': instance.queuedAt.toIso8601String(),
      'retry_count': instance.retryCount,
    };
