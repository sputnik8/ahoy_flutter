import 'package:json_annotation/json_annotation.dart';

part 'update_attribution_request_input.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class UpdateAttributionRequestInput {
  final String visitToken;
  final String? landingPage;
  final String? utmSource;
  final String? utmMedium;
  final String? utmTerm;
  final String? utmCampaign;

  UpdateAttributionRequestInput({
    required this.visitToken,
    this.landingPage,
    this.utmSource,
    this.utmMedium,
    this.utmTerm,
    this.utmCampaign,
  });

  factory UpdateAttributionRequestInput.fromJson(Map<String, dynamic> json) =>
      _$UpdateAttributionRequestInputFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateAttributionRequestInputToJson(this);
}
