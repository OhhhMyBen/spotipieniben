import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../providers/app_providers.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/duration_formatter.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final bytes = await ref.read(artworkServiceProvider).getCacheSizeBytes();
    if (mounted) {
      setState(() => _cacheBytes = bytes);
    }
  }

  Future<void> _showIncludedFoldersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final folders =
              ref.watch(libraryProvider.select((l) => l.discoveredFolders));
          final excluded = ref.watch(
            settingsProvider.select((s) => s.excludedFolders.toSet()),
          );

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Included Music Folders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Uncheck folders to hide them from your library',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (folders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No local audio folders discovered yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: folders.length,
                        itemBuilder: (_, idx) {
                          final folder = folders[idx];
                          final included = !excluded.contains(folder);
                          return CheckboxListTile(
                            value: included,
                            activeColor: AppColors.primaryAccent,
                            checkColor: Colors.white,
                            title: Text(
                              folder.split('/').last.isEmpty
                                  ? folder
                                  : folder.split('/').last,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              folder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                            onChanged: (_) => ref
                                .read(settingsProvider.notifier)
                                .toggleFolderIncluded(folder),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final libState = ref.watch(libraryProvider);
    final visibleTracks = ref.watch(visibleTracksProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final activeFolderCount = libState.discoveredFolders
        .where((f) => !settings.excludedFolders.contains(f))
        .length;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Section 1: Library & Scanning
          const _SectionHeader(title: 'LIBRARY & SCANNING'),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.library_music_rounded,
                        color: AppColors.softLavender,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rescan Local Storage',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${visibleTracks.length} tracks indexed (${libState.allScannedTracks.length} total)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: libState.isScanning
                          ? null
                          : () => ref
                              .read(libraryProvider.notifier)
                              .rescanLibrary(),
                      icon: libState.isScanning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded, size: 17),
                      label: Text(libState.isScanning ? 'Scanning' : 'Rescan'),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.borderHairline, height: 1),
              ListTile(
                leading: const _IconBox(icon: Icons.folder_copy_outlined),
                title: const Text(
                  'Included Folders',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '$activeFolderCount of ${libState.discoveredFolders.length} folders selected',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
                onTap: _showIncludedFoldersSheet,
              ),
              const Divider(color: AppColors.borderHairline, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Minimum Track Duration',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${settings.minDurationSeconds}s',
                          style: AppTheme.tabularTimeStyle(
                            fontSize: 13.5,
                            color: AppColors.softLavender,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Filter out short ringtones, SFX, and voice notes',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primaryAccent,
                        inactiveTrackColor: AppColors.surfaceContainerHighest,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: settings.minDurationSeconds.toDouble(),
                        min: 0,
                        max: 120,
                        divisions: 24,
                        onChanged: (val) => settingsNotifier
                            .setMinDurationSeconds(val.round()),
                        onChangeEnd: (_) => ref
                            .read(libraryProvider.notifier)
                            .rescanLibrary(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Section 2: Lyrics Preferences
          const _SectionHeader(title: 'LYRICS PREFERENCES'),
          _SettingsCard(
            children: [
              SwitchListTile.adaptive(
                value: settings.preferExternalLrc,
                activeTrackColor: AppColors.primaryAccent,
                secondary: const _IconBox(icon: Icons.subtitles_outlined),
                title: const Text(
                  'Prefer External .LRC over Embedded ID3',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Load sibling .lrc file before embedded ID3 USLT/SYLT tags',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onChanged: settingsNotifier.setPreferExternalLrc,
              ),
              const Divider(color: AppColors.borderHairline, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lyric Font Size',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: LyricFontSize.values.map((size) {
                          final selected = settings.lyricFontSize == size;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  settingsNotifier.setLyricFontSize(size),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primaryAccent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  size.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.borderHairline, height: 1),
              SwitchListTile.adaptive(
                value: settings.autoScrollLyrics,
                activeTrackColor: AppColors.primaryAccent,
                secondary: const _IconBox(icon: Icons.vertical_align_center_rounded),
                title: const Text(
                  'Auto-scroll Lyrics',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Keep active vocal line centered during playback',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onChanged: settingsNotifier.setAutoScrollLyrics,
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Section 3: Playback & Audio
          const _SectionHeader(title: 'PLAYBACK & AUDIO'),
          _SettingsCard(
            children: [
              SwitchListTile.adaptive(
                value: settings.gaplessPlayback,
                activeTrackColor: AppColors.primaryAccent,
                secondary: const _IconBox(icon: Icons.all_inclusive_rounded),
                title: const Text(
                  'Gapless Playback',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Preload queued tracks for seamless transitions',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onChanged: settingsNotifier.setGaplessPlayback,
              ),
              const Divider(color: AppColors.borderHairline, height: 1),
              SwitchListTile.adaptive(
                value: settings.pauseOnHeadsetDisconnect,
                activeTrackColor: AppColors.primaryAccent,
                secondary: const _IconBox(icon: Icons.headphones_rounded),
                title: const Text(
                  'Pause on Headset Disconnect',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Auto-pause when wired or Bluetooth headphones unplug',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onChanged: settingsNotifier.setPauseOnHeadsetDisconnect,
              ),
              const Divider(color: AppColors.borderHairline, height: 1),
              ListTile(
                leading: const _IconBox(icon: Icons.cleaning_services_outlined),
                title: const Text(
                  'Clear Artwork & Metadata Cache',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${formatFileSize(_cacheBytes)} cached artwork on device',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    await ref.read(artworkServiceProvider).clearCache();
                    await ref
                        .read(storageServiceProvider)
                        .clearMetadataCache();
                    await _loadCacheSize();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Artwork and metadata cache cleared'),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Section 4: About
          const _SectionHeader(title: 'ABOUT'),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icon/appicon.jpg',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SpotipieNiBen',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Version 1.0.0 • Purple Mode Local Player',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    AppColors.emerald.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.offline_bolt_rounded,
                                  size: 14,
                                  color: AppColors.emerald,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  '100% OFFLINE MODE ACTIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: AppColors.emerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: AppColors.softLavender,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderHairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.softLavender, size: 19),
    );
  }
}
