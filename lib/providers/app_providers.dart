import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/artwork_service.dart';
import '../services/audio_handler.dart';
import '../services/library_scanner_service.dart';
import '../services/lyrics_service.dart';
import '../services/permissions_service.dart';
import '../services/storage_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final audioHandlerProvider = Provider<AuraAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden');
});

final onAudioQueryProvider = Provider<OnAudioQuery>((ref) {
  return OnAudioQuery();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(sharedPreferencesProvider));
});

final permissionsServiceProvider = Provider<PermissionsService>((ref) {
  return PermissionsService(ref.watch(onAudioQueryProvider));
});

final artworkServiceProvider = Provider<ArtworkService>((ref) {
  return ArtworkService(ref.watch(onAudioQueryProvider));
});

final lyricsServiceProvider = Provider<LyricsService>((ref) {
  return LyricsService(ref.watch(storageServiceProvider));
});

final libraryScannerServiceProvider = Provider<LibraryScannerService>((ref) {
  return LibraryScannerService(
    ref.watch(onAudioQueryProvider),
    ref.watch(storageServiceProvider),
  );
});
