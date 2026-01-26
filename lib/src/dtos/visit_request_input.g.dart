// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visit_request_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VisitRequestInput _$VisitRequestInputFromJson(Map<String, dynamic> json) =>
    VisitRequestInput(
      visitToken: json['visit_token'] as String,
      visitorToken: json['visitor_token'] as String,
      userId: json['user_id'] as String?,
      userAgent: json['user_agent'] as String?,
      appVersion: json['app_version'] as String?,
      os: json['os'] as String?,
      osVersion: json['os_version'] as String?,
      platform: json['platform'] as String?,
      deviceType: json['device_type'] as String?,
      landingPage: json['landing_page'] as String?,
      utmSource: json['utm_source'] as String?,
      utmMedium: json['utm_medium'] as String?,
      utmTerm: json['utm_term'] as String?,
      utmCampaign: json['utm_campaign'] as String?,
      startedAt: json['started_at'] as String?,
      additionalParams: json['additional_params'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$VisitRequestInputToJson(VisitRequestInput instance) =>
    <String, dynamic>{
      'visit_token': instance.visitToken,
      'visitor_token': instance.visitorToken,
      if (instance.userId case final value?) 'user_id': value,
      if (instance.userAgent case final value?) 'user_agent': value,
      if (instance.appVersion case final value?) 'app_version': value,
      if (instance.os case final value?) 'os': value,
      if (instance.osVersion case final value?) 'os_version': value,
      if (instance.platform case final value?) 'platform': value,
      if (instance.deviceType case final value?) 'device_type': value,
      if (instance.landingPage case final value?) 'landing_page': value,
      if (instance.utmSource case final value?) 'utm_source': value,
      if (instance.utmMedium case final value?) 'utm_medium': value,
      if (instance.utmTerm case final value?) 'utm_term': value,
      if (instance.utmCampaign case final value?) 'utm_campaign': value,
      if (instance.startedAt case final value?) 'started_at': value,
      if (instance.additionalParams case final value?)
        'additional_params': value,
    };
