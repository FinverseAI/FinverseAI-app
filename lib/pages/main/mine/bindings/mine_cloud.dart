import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers.dart';

/// Pending local changes: rows in the Drift `LocalChanges` table whose
/// `pushedAt` is still null. FinVerse v1 is local-only, so nothing pushes
/// yet — the count only grows until the FinVerse sync layer lands. It is
/// shown so the user can see nothing is lost while sync is unavailable.
final _pendingChangesProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(db.localChanges)
        ..where((c) => c.pushedAt.isNull()))
      .get();
  return rows.length;
});

/// FinVerse sync status (local-only for v1).
///
/// The BeeCount Cloud status this binding used to show is gone: no cloud
/// account, no sync engine. The row states plainly that FinVerse sync
/// arrives with the backend wiring, and shows how many local changes are
/// waiting to sync once it does. No backend calls are made here.
class MineCloudBinding extends ConsumerWidget {
  const MineCloudBinding({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingChangesProvider);
    final detail = pending.when(
      loading: () => 'FinVerse sync arrives with backend wiring.',
      error: (_, __) => 'FinVerse sync arrives with backend wiring.',
      data: (count) => count == 0
          ? 'FinVerse sync arrives with backend wiring. Nothing pending.'
          : 'FinVerse sync arrives with backend wiring. '
              '$count change${count == 1 ? '' : 's'} waiting to sync.',
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      BeeMenuRow(
        title: 'FinVerse Sync',
        leading: const BeeLineIcon('Cloud', size: 19),
        subtitle: detail,
      ),
    ]);
  }
}
