enum LyricFontSize {
  small,
  medium,
  large,
}

extension LyricFontSizeX on LyricFontSize {
  String get label {
    switch (this) {
      case LyricFontSize.small:
        return 'Small';
      case LyricFontSize.medium:
        return 'Medium';
      case LyricFontSize.large:
        return 'Large';
    }
  }

  double get activeSize {
    switch (this) {
      case LyricFontSize.small:
        return 21;
      case LyricFontSize.medium:
        return 25;
      case LyricFontSize.large:
        return 29;
    }
  }

  double get inactiveSize {
    switch (this) {
      case LyricFontSize.small:
        return 16;
      case LyricFontSize.medium:
        return 18;
      case LyricFontSize.large:
        return 21;
    }
  }
}

class AppSettings {
  final int minDurationSeconds;
  final List<String> excludedFolders;
  final bool preferExternalLrc;
  final LyricFontSize lyricFontSize;
  final bool autoScrollLyrics;
  final bool gaplessPlayback;
  final bool pauseOnHeadsetDisconnect;

  const AppSettings({
    this.minDurationSeconds = 30,
    this.excludedFolders = const [],
    this.preferExternalLrc = true,
    this.lyricFontSize = LyricFontSize.medium,
    this.autoScrollLyrics = true,
    this.gaplessPlayback = true,
    this.pauseOnHeadsetDisconnect = true,
  });

  AppSettings copyWith({
    int? minDurationSeconds,
    List<String>? excludedFolders,
    bool? preferExternalLrc,
    LyricFontSize? lyricFontSize,
    bool? autoScrollLyrics,
    bool? gaplessPlayback,
    bool? pauseOnHeadsetDisconnect,
  }) {
    return AppSettings(
      minDurationSeconds: minDurationSeconds ?? this.minDurationSeconds,
      excludedFolders: excludedFolders ?? this.excludedFolders,
      preferExternalLrc: preferExternalLrc ?? this.preferExternalLrc,
      lyricFontSize: lyricFontSize ?? this.lyricFontSize,
      autoScrollLyrics: autoScrollLyrics ?? this.autoScrollLyrics,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      pauseOnHeadsetDisconnect:
          pauseOnHeadsetDisconnect ?? this.pauseOnHeadsetDisconnect,
    );
  }

  Map<String, dynamic> toJson() => {
        'minDurationSeconds': minDurationSeconds,
        'excludedFolders': excludedFolders,
        'preferExternalLrc': preferExternalLrc,
        'lyricFontSize': lyricFontSize.name,
        'autoScrollLyrics': autoScrollLyrics,
        'gaplessPlayback': gaplessPlayback,
        'pauseOnHeadsetDisconnect': pauseOnHeadsetDisconnect,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final sizeName = json['lyricFontSize'] as String? ?? 'medium';
    final fontSize = LyricFontSize.values.firstWhere(
      (e) => e.name == sizeName,
      orElse: () => LyricFontSize.medium,
    );

    return AppSettings(
      minDurationSeconds: (json['minDurationSeconds'] as num?)?.toInt() ?? 30,
      excludedFolders:
          List<String>.from(json['excludedFolders'] as List? ?? const []),
      preferExternalLrc: json['preferExternalLrc'] as bool? ?? true,
      lyricFontSize: fontSize,
      autoScrollLyrics: json['autoScrollLyrics'] as bool? ?? true,
      gaplessPlayback: json['gaplessPlayback'] as bool? ?? true,
      pauseOnHeadsetDisconnect:
          json['pauseOnHeadsetDisconnect'] as bool? ?? true,
    );
  }
}
