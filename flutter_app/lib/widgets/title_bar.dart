import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../models/connection_status.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// Frameless-window title bar shown only on Windows desktop.
/// Left: bunny mascot tile + name + version chip. Center: live carrier ·
/// transport context (mono). Right: window controls (close hovers vp8).
class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();
    final app = context.watch<AppState>();
    final t = app.telemetry;
    final connected = t.state == VpnState.connected;
    final center = connected
        ? '${(t.carrier ?? 'olcrtc').toLowerCase()} · '
            '${(t.transport ?? '').isEmpty ? 'datachannel' : t.transport}'
        : 'локальный SOCKS · 127.0.0.1:10808';

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(
            bottom: BorderSide(color: AppColors.line),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            // bunny mascot on a black tile
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/icons/ic_launcher.png',
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 9),
            const Text(
              'XLTD VPN',
              style: TextStyle(
                fontFamily: kFontSans,
                color: AppColors.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'v2.2.0 · WIN-X64',
                style: TextStyle(
                  fontFamily: kFontMono,
                  color: AppColors.textDim,
                  fontSize: 9.5,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  center,
                  style: const TextStyle(
                    fontFamily: kFontMono,
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            _WindowButton(
              icon: Icons.remove,
              onPressed: () => windowManager.minimize(),
            ),
            _WindowButton(
              icon: Icons.crop_square,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: Icons.close,
              hoverColor: AppColors.vp8.withOpacity(0.85),
              hoverIconColor: Colors.white,
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? hoverColor;
  final Color? hoverIconColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 44,
          color: _hover
              ? (widget.hoverColor ?? AppColors.surface)
              : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 14,
            color: _hover
                ? (widget.hoverIconColor ?? AppColors.textTertiary)
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
