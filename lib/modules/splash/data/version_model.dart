class VersionResponse {
  final String? latestVersion;
  final String? minVersion;
  final String? downloadUrl;

  VersionResponse({
    this.latestVersion,
    this.minVersion,
    this.downloadUrl,
  });

  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      latestVersion: json['latest_version'] as String?,
      minVersion: json['min_version'] as String?,
      downloadUrl: json['download_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'latest_version': latestVersion,
    'min_version': minVersion,
    'download_url': downloadUrl,
  };
}
