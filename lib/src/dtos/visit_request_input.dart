import 'package:json_annotation/json_annotation.dart';

part 'visit_request_input.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class VisitRequestInput {
  final String visitToken;
  final String visitorToken;
  final String? userId;
  final String? userAgent;
  final String? appVersion;
  final String? os;
  final String? osVersion;
  final String? platform;
  final String? deviceType;
  final String? landingPage;
  final String? utmSource;
  final String? utmMedium;
  final String? utmTerm;
  final String? utmCampaign;
  final String? startedAt;
  final Map<String, dynamic>? additionalParams;

  VisitRequestInput({
    required this.visitToken,
    required this.visitorToken,
    this.userId,
    this.userAgent,
    this.appVersion,
    this.os,
    this.osVersion,
    this.platform,
    this.deviceType,
    this.landingPage,
    this.utmSource,
    this.utmMedium,
    this.utmTerm,
    this.utmCampaign,
    this.startedAt,
    this.additionalParams,
  });

  factory VisitRequestInput.fromJson(Map<String, dynamic> json) =>
      _$VisitRequestInputFromJson(json);

  Map<String, dynamic> toJson() => _$VisitRequestInputToJson(this);
}
