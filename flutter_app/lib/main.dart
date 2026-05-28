import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/shell.dart';
import 'services/profiles_store.dart';
import 'services/vpn_bridge.dart';
import 'state/app_state.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(1200, 780),
      minimumSize: Size(960, 620),
      backgroundColor: Color(0xFF0E1014),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'XLTD VPN',
    );
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final state = AppState(ProfilesStore(), Vpn.instance);

  runApp(ChangeNotifierProvider.value(
    value: state,
    child: const XLTDApp(),
  ));
}

class XLTDApp extends StatelessWidget {
  const XLTDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XLTD VPN',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
