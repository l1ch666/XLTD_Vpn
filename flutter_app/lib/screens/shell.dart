import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/side_nav.dart';
import '../widgets/title_bar.dart';
import 'home_screen.dart';
import 'log_screen.dart';
import 'profiles_screen.dart';
import 'settings_screen.dart';
import 'traffic_screen.dart';

/// Top-level shell. Picks between desktop layout (title bar + side nav)
/// and mobile layout (full-screen + bottom nav).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  Widget _page() {
    switch (_tab) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ProfilesScreen();
      case 2:
        return const TrafficScreen();
      case 3:
        return const SettingsScreen();
      case 4:
        return const LogScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows;
    if (!isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: _page()),
        bottomNavigationBar: BottomNav(
          activeIndex: _tab.clamp(0, 3),
          onSelect: (i) => setState(() => _tab = i),
        ),
      );
    }
    // Desktop: rail + content
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const TitleBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SideNav(
                  activeIndex: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: _page()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
