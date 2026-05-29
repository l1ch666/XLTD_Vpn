import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/transport.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'app_icon.dart';
import 'signal_bars.dart';

/// One profile in the home list / profiles screen.
///
/// `_design_drop` profile row: active dot + 32×32 SVG glyph tile + title/meta +
/// trailing signal bars (home/compact) or an "изменить" action (profiles/full).
class ProfileRow extends StatelessWidget {
  final Profile profile;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onLongPress;

  /// Signal-bar quality level 1..4 (compact mode only). Defaults from state.
  final int? level;

  const ProfileRow({
    super.key,
    required this.profile,
    required this.active,
    required this.onTap,
    this.onEdit,
    this.onLongPress,
    this.level,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _metaLine(profile);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: active ? AppColors.lineStrong : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // active dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? AppColors.ok : AppColors.line,
                shape: BoxShape.circle,
                boxShadow:
                    active ? [const BoxShadow(color: AppColors.ok, blurRadius: 8)] : null,
              ),
            ),
            const SizedBox(width: 9),
            // glyph tile
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: AppIcon(
                AppIcon.transportAsset(profile.transport),
                size: 18,
                color: AppColors.primaryLt,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_displayCarrier(profile.carrier)} · ${Transport.label(profile.transport)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: kFontMono,
                      fontSize: 10,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                  child: Text(
                    'изменить',
                    style: TextStyle(
                      fontFamily: kFontMono,
                      fontSize: 10,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
            else
              SignalBars(
                level: level ?? (active ? 3 : 2),
                active: active,
              ),
          ],
        ),
      ),
    );
  }

  String _displayCarrier(String c) => c.isEmpty ? 'olcRTC' : c;

  String _metaLine(Profile p) {
    // Prefer a transport-channel + carrier descriptor.
    final t = p.transport.isEmpty ? 'datachannel' : p.transport;
    if (p.comment.isNotEmpty && p.comment != '${p.carrier} · ${p.transport}') {
      return '$t · ${p.comment}';
    }
    return '$t · ${_displayCarrier(p.carrier)}';
  }
}
