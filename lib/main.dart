import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_providers.dart';
import 'screens/main_shell.dart';
import 'services/artwork_service.dart';
import 'services/audio_handler.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.backgroundPrimary,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final audioQuery = OnAudioQuery();
  final artworkService = ArtworkService(audioQuery);

  final audioHandler = await AudioService.init(
    builder: () => AuraAudioHandler(artworkService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.purplespotify.channel.audio',
      androidNotificationChannelName: 'SpotipieNiBen Playback',
      androidNotificationChannelDescription:
          'Offline Purple Mode audio playback controls',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      notificationColor: AppColors.primaryAccent,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        onAudioQueryProvider.overrideWithValue(audioQuery),
        artworkServiceProvider.overrideWithValue(artworkService),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const AuraMusicApp(),
    ),
  );
}

class AuraMusicApp extends StatelessWidget {
  const AuraMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotipieNiBen',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme(),
      theme: AppTheme.darkTheme(),
      home: const MainShell(),
    );
  }
}
