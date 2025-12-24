// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Visit _$VisitFromJson(Map<String, dynamic> json) => Visit(
      visitorToken: json['visitor_token'] as String,
      visitToken: json['visit_token'] as String,
      visitId: json['visit_id'] as String?,
      visitorId: json['visitor_id'] as String?,
      userId: json['user_id'] as String?,
      additionalParams: json['additional_params'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$VisitToJson(Visit instance) => <String, dynamic>{
      'visitor_token': instance.visitorToken,
      'visit_token': instance.visitToken,
      if (instance.visitId case final value?) 'visit_id': value,
      if (instance.visitorId case final value?) 'visitor_id': value,
      if (instance.userId case final value?) 'user_id': value,
      if (instance.additionalParams case final value?)
        'additional_params': value,
    };
