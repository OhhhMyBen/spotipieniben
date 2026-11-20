import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_track.dart';
import '../providers/app_providers.dart';
import '../providers/library_provider.dart';
import '../services/permissions_service.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_mini_player.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'search_tab.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  final GlobalKey<LibraryTabState> _libraryKey = GlobalKey<LibraryTabState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(libraryProvider.notifier).refreshPermissionStatus();
    }
  }

  void _openAlbumInLibrary(LocalAlbum album) {
    setState(() => _tabIndex = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _libraryKey.currentState?.openAlbum(album);
    });
  }

  void _openArtistInLibrary(LocalArtist artist) {
    setState(() => _tabIndex = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _libraryKey.currentState?.openArtist(artist);
    });
  }

  @override
  Widget build(BuildContext context) {
    final libState = ref.watch(libraryProvider);

    if (libState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryAccent),
              SizedBox(height: 16),
              Text(
                'Initializing SpotipieNiBen...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (libState.permissionStatus != AudioPermissionResult.granted) {
      return _PermissionPromptView(
        permanentlyDenied:
            libState.permissionStatus == AudioPermissionResult.permanentlyDenied,
        onRequestPermission: () =>
            ref.read(libraryProvider.notifier).requestPermissionAndScan(),
        onOpenSettings: () =>
            ref.read(permissionsServiceProvider).openSettings(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IndexedStack(
              index: _tabIndex,
              children: [
                HomeTab(onOpenAlbum: _openAlbumInLibrary),
                SearchTab(
                  onOpenAlbum: _openAlbumInLibrary,
                  onOpenArtist: _openArtistInLibrary,
                ),
                LibraryTab(key: _libraryKey),
              ],
            ),
            // Pinned Floating Mini-Player + Bottom Nav Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FloatingMiniPlayer(),
                  _PurpleBottomNavBar(
                    currentIndex: _tabIndex,
                    onTap: (i) => setState(() => _tabIndex = i),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurpleBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PurpleBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary.withValues(alpha: 0.92),
            border: const Border(
              top: BorderSide(color: AppColors.borderHairline),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    selected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.library_music_rounded,
                    label: 'Library',
                    selected: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.primaryAccent : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 84,
        height: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 5 : 0,
              height: selected ? 5 : 0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryAccent,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryAccent.withValues(alpha: 0.9),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionPromptView extends StatelessWidget {
  final bool permanentlyDenied;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;

  const _PermissionPromptView({
    required this.permanentlyDenied,
    required this.onRequestPermission,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderPurpleSubtle),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.16),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.secondaryAccent,
                          AppColors.primaryAccent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryAccent.withValues(alpha: 0.45),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.library_music_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Access Local Music',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    permanentlyDenied
                        ? 'Audio permission was denied. Enable Music & Audio access in system settings so SpotipieNiBen can scan your local files and .lrc lyrics.'
                        : 'SpotipieNiBen plays 100% offline. Grant local audio access to scan your .mp3, .flac, .m4a, .wav, and .ogg tracks along with synced .lrc lyrics.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: permanentlyDenied
                          ? onOpenSettings
                          : onRequestPermission,
                      child: Text(
                        permanentlyDenied
                            ? 'Open System Settings'
                            : 'Allow Audio Access',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (permanentlyDenied) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: onRequestPermission,
                      child: const Text(
                        'Try Checking Again',
                        style: TextStyle(color: AppColors.softLavender),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
