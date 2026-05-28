import 'package:flutter/material.dart';

import '../models/connection_status.dart';
import '../theme/colors.dart';

/// Large action button — gradient blue when offline, red-tinted when connected.
class ConnectButton extends StatelessWidget {
  final VpnState state;
  final VoidCallback onPressed;
  final bool dense;

  const ConnectButton({
    super.key,
    required this.state,
    required this.onPressed,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = state == VpnState.connected ||
        state == VpnState.reconnecting;
    final busy = state == VpnState.connecting;
    final label = switch (state) {
      VpnState.connected => 'Отключить',
      VpnState.connecting => 'Подключение…',
      VpnState.reconnecting => 'Переподключение',
      VpnState.failed => 'Повторить',
      VpnState.disconnected => 'Подключиться',
    };

    final gradient = isOn
        ? const [Color(0xFF2A2D36), Color(0xFF1E1F26)]
        : AppColors.connectGradient;
    final fg = isOn ? AppColors.text : AppColors.text;
    final borderColor =
        isOn ? AppColors.border : Colors.transparent;

    return InkWell(
      onTap: busy ? null : onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: dense ? 44 : 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: isOn
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.text),
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}
