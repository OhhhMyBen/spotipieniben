import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

enum AudioPermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

class PermissionsService {
  final OnAudioQuery _audioQuery;

  PermissionsService(this._audioQuery);

  Future<AudioPermissionResult> checkPermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      return AudioPermissionResult.granted;
    }

    final audioStatus = await Permission.audio.status;
    if (audioStatus.isGranted) return AudioPermissionResult.granted;

    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return AudioPermissionResult.granted;

    // Fallback check via on_audio_query in case SDK level maps differently
    final hasQueryPerm = await _audioQuery.permissionsStatus();
    if (hasQueryPerm) return AudioPermissionResult.granted;

    if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      return AudioPermissionResult.permanentlyDenied;
    }
    return AudioPermissionResult.denied;
  }

  Future<AudioPermissionResult> requestAudioPermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      return AudioPermissionResult.granted;
    }

    // Request READ_MEDIA_AUDIO (Android 13+) and READ_EXTERNAL_STORAGE (<= Android 12)
    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) {
      await _requestNotificationPermissionIfNeeded();
      return AudioPermissionResult.granted;
    }

    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) {
      await _requestNotificationPermissionIfNeeded();
      return AudioPermissionResult.granted;
    }

    final queryGranted = await _audioQuery.checkAndRequest(retryRequest: true);
    if (queryGranted) {
      await _requestNotificationPermissionIfNeeded();
      return AudioPermissionResult.granted;
    }

    if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      return AudioPermissionResult.permanentlyDenied;
    }
    return AudioPermissionResult.denied;
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      final notifStatus = await Permission.notification.status;
      if (notifStatus.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Safe no-op on older Android versions
    }
  }

  Future<bool> openSettings() => openAppSettings();
}
