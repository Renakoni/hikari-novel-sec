enum TtsProviderType {
  system,
  volcengine;

  String get storageValue => switch (this) {
    TtsProviderType.system => "system",
    TtsProviderType.volcengine => "volcengine",
  };

  static TtsProviderType fromStorage(String? value) {
    return TtsProviderType.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => TtsProviderType.system,
    );
  }
}
