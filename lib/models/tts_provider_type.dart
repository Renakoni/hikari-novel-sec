enum TtsProviderType {
  system,
  volcengine,
  google;

  String get storageValue => switch (this) {
    TtsProviderType.system => "system",
    TtsProviderType.volcengine => "volcengine",
    TtsProviderType.google => "google",
  };

  static TtsProviderType fromStorage(String? value) {
    return TtsProviderType.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => TtsProviderType.system,
    );
  }
}
