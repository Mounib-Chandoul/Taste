import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/core.dart';
import '../providers/app_providers.dart';
import '../providers/session_actions.dart';
import '../widgets/mini_player.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/settings/settings_screen.dart';

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _navItems = <_NavItem>[
  _NavItem(PhosphorIconsRegular.house, PhosphorIconsFill.house, 'Home'),
  _NavItem(PhosphorIconsRegular.magnifyingGlass,
      PhosphorIconsFill.magnifyingGlass, 'Search'),
  _NavItem(PhosphorIconsRegular.playlist, PhosphorIconsFill.playlist, 'Library'),
  _NavItem(PhosphorIconsRegular.gearSix, PhosphorIconsFill.gearSix, 'Settings'),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final PageController _pageController;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(shellTabProvider);
    _pageController = PageController(initialPage: initial);
    // Cheap ETag revalidation keeps newly added songs visible without a
    // manual rescan/restart. A 304 costs one small request and no JSON parse.
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(syncLibrary(ref));
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    ref.read(shellTabProvider.notifier).state = index;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
    );
  }

  void _onPageChanged(int index) {
    ref.read(shellTabProvider.notifier).state = index;
  }

  void _openNowPlaying() {
    context.push('/now-playing');
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellTabProvider);
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 700;

    final pages = <Widget>[
      const HomeScreen(),
      const SearchScreen(),
      const LibraryScreen(),
      const SettingsScreen(),
    ];

    final pageView = PageView(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      physics: const BouncingScrollPhysics(),
      children: pages,
    );

    final mini = MiniPlayer(onExpand: _openNowPlaying);

    if (useRail) {
      return Scaffold(
        backgroundColor: colors.background,
        body: GridBackground(
          child: SafeArea(
            child: Row(
              children: [
                _LeftRail(
                  index: index,
                  onSelect: _goTo,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: pageView),
                      mini,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: GridBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: pageView),
              mini,
              _BottomNav(index: index, onSelect: _goTo),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeftRail extends StatelessWidget {
  const _LeftRail({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      child: PixelCard(
        radius: 16,
        borderWidth: 2.5,
        shadowOffset: const Offset(5, 5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        color: colors.card,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border, width: 2),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _navItems.length; i++) ...[
                _RailButton(
                  item: _navItems[i],
                  selected: i == index,
                  dotColor: colors.accentCycle[i % colors.accentCycle.length],
                  onTap: () => onSelect(i),
                ),
                const SizedBox(height: 10),
              ],
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.cyan,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.selected,
    required this.dotColor,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final Color dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelButton.icon(
          icon: selected ? item.activeIcon : item.icon,
          onTap: onTap,
          size: 44,
          iconSize: 22,
          iconColor: selected ? colors.accent : colors.textSecondary,
          selected: selected,
          color: selected ? colors.cardElevated : colors.card,
          borderColor: selected ? colors.accent : colors.border,
          tooltip: item.label,
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? dotColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? dotColor : colors.border,
              width: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: PixelCard(
          radius: 16,
          borderWidth: 2.5,
          shadowOffset: const Offset(4, 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: colors.card,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _navItems.length; i++)
                _BottomNavItem(
                  item: _navItems[i],
                  selected: i == index,
                  dotColor: colors.accentCycle[i % colors.accentCycle.length],
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.dotColor,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final Color dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.cardElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.border : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: selected ? colors.accent : colors.textSecondary,
            ),
            const SizedBox(height: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? dotColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
