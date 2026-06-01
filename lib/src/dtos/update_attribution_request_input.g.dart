// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_attribution_request_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateAttributionRequestInput _$UpdateAttributionRequestInputFromJson(
        Map<String, dynamic> json) =>
    UpdateAttributionRequestInput(
      visitToken: json['visit_token'] as String,
      landingPage: json['landing_page'] as String?,
      utmSource: json['utm_source'] as String?,
      utmMedium: json['utm_medium'] as String?,
      utmTerm: json['utm_term'] as String?,
      utmCampaign: json['utm_campaign'] as String?,
      additionalParams: json['additional_params'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$UpdateAttributionRequestInputToJson(
        UpdateAttributionRequestInput instance) =>
    <String, dynamic>{
      'visit_token': instance.visitToken,
      if (instance.landingPage case final value?) 'landing_page': value,
      if (instance.utmSource case final value?) 'utm_source': value,
      if (instance.utmMedium case final value?) 'utm_medium': value,
      if (instance.utmTerm case final value?) 'utm_term': value,
      if (instance.utmCampaign case final value?) 'utm_campaign': value,
      if (instance.additionalParams case final value?)
        'additional_params': value,
    };
