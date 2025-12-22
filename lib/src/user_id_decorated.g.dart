// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_id_decorated.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserIdDecorated<T> _$UserIdDecoratedFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    UserIdDecorated<T>(
      userId: json['user_id'] as String?,
      wrapped: fromJsonT(json['wrapped']),
    );

Map<String, dynamic> _$UserIdDecoratedToJson<T>(
  UserIdDecorated<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      if (instance.userId case final value?) 'user_id': value,
      'wrapped': toJsonT(instance.wrapped),
    };
