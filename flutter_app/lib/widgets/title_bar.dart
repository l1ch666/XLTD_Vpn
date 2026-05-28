import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../models/connection_status.dart';
import '../models/transport.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';

/// Frameless-window title bar shown only on Windows desktop.
/// Center label updates to the active carrier when connected.
class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();
    final app = context.watch<AppState>();
    final connected = app.telemetry.state == VpnState.connected;
    final center = connected
        ? '${app.telemetry.carrier?.toUpperCase() ?? ''} · '
            '${Transport.label(app.telemetry.transport ?? '')}'
        : 'XLTD VPN';

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 36,
        color: AppColors.bg,
        child: Row(
          children: [
            const SizedBox(width: 12),
            // brand
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: connected ? AppColors.ok : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'XLTD VPN',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'v2.0.0',
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Text(
                  center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
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
              hoverColor: AppColors.err.withOpacity(0.25),
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

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.hoverColor,
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
          width: 44,
          height: 36,
          color: _hover
              ? (widget.hoverColor ?? AppColors.surface)
              : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 14, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
