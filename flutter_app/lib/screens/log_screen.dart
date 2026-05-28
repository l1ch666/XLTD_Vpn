import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/colors.dart';
import '../widgets/event_row.dart';
import '../widgets/panel.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final events = app.events.toList().reversed.toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                PanelLabel('RUNTIME LOG'),
                Spacer(),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 6),
            Expanded(
              child: events.isEmpty
                  ? const Center(
                      child: Text(
                        'тишина в эфире',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (_, i) => EventRow(event: events[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
