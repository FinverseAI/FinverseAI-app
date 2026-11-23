import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../models/ledger_display_item.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'ledgers/widgets/ledger_card.dart';
import '../budget/budget_page.dart';
import '../../utils/currencies.dart';
import '../../services/attachment_service.dart';
import '../../services/system/logger_service.dart';
import '../../utils/format_utils.dart';
import '../../services/billing/post_processor.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/budget_providers.dart';
import '../../widget/widget_manager.dart';

import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../shared/selectors/currency_picker_sheet.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';

part 'ledgers/bindings/ledger_actions.dart';
part 'ledgers/widgets/ledger_overview.dart';

/// 本地账本列表(个人账本切换器的数据源)。FinVerse v1 只有本地单人账本:直接读
/// Drift + 本地统计,不再经过云同步的 local/remote 两路 provider。
/// ledger_picker_sheet.dart 也用它。
final localLedgersProvider =
    FutureProvider<List<LedgerDisplayItem>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  ref.watch(statsRefreshProvider);
  final ledgers = await repo.getAllLedgers();
  final accountFeatureEnabled =
      await ref.watch(accountFeatureEnabledProvider.future);
  final items = <LedgerDisplayItem>[];
  for (final ledger in ledgers) {
    final stats = await repo.getLedgerStats(
        ledgerId: ledger.id,
        accountFeatureEnabled: accountFeatureEnabled);
    items.add(LedgerDisplayItem.fromLocal(
      id: ledger.id,
      name: ledger.name,
      currency: ledger.currency,
      createdAt: ledger.createdAt,
      transactionCount: stats.transactionCount,
      balance: stats.balance,
      isShared: ledger.isShared,
      myRole: ledger.myRole,
    ));
  }
  return items;
});

class LedgersPageNew extends ConsumerStatefulWidget {
  const LedgersPageNew({super.key, this.autoOpenCreateDialog = false});
  final bool autoOpenCreateDialog;
  @override
  ConsumerState<LedgersPageNew> createState() => _LedgersPageNewState();
}

class _LedgersPageNewState extends ConsumerState<LedgersPageNew>
    with _LedgerActions, _LedgerOverview {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenCreateDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCreateLedgerDialog(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentId = ref.watch(currentLedgerIdProvider);
    final local = ref.watch(localLedgersProvider);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.ledgersTitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: l.ledgersCreate,
                icon: const BeeLineIcon('Plus'),
                onPressed: () => _showCreateLedgerDialog(context)),
            BeeIconButton(
                label: MaterialLocalizations.of(context)
                    .refreshIndicatorSemanticLabel,
                icon: const BeeLineIcon('RefreshCw'),
                onPressed: () => ref.invalidate(localLedgersProvider)),
          ]),
      Expanded(
          child: _buildProgressiveList(context, ref, currentId, local)),
    ]));
  }
}
