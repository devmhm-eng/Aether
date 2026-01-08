// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'version_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VersionResponse _$VersionResponseFromJson(Map<String, dynamic> json) =>
    VersionResponse(
      latestVersion: json['latest_version'] as String,
      minVersion: json['min_version'] as String,
      downloadUrl: json['download_url'] as String,
    );

Map<String, dynamic> _$VersionResponseToJson(VersionResponse instance) =>
    <String, dynamic>{
      'latest_version': instance.latestVersion,
      'min_version': instance.minVersion,
      'download_url': instance.downloadUrl,
    };
