/// 账本卡片组件
///
/// 展示账本基本信息。FinVerse v1 是本地单人账本,没有同步状态可展示。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/ledger_display_item.dart';
import '../../../../providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../../../utils/format_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../styles/tokens.dart';

/// 账本卡片
class LedgerCard extends ConsumerWidget {
  final LedgerDisplayItem ledger;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 右下角「⋯」按钮回调 —— 与 [onLongPress] 调同一个操作菜单。
  /// 长按是不可发现的手势,预算管理等入口藏在里面没人找得到,
  /// 必须有一个可见的等价入口。
  final VoidCallback? onMore;
  final bool selected;
  final VoidCallback? onBudget, onEdit, onMembers;

  const LedgerCard({
    super.key,
    required this.ledger,
    this.onTap,
    this.onLongPress,
    this.onMore,
    this.selected = false,
    this.onBudget,
    this.onEdit,
    this.onMembers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // FinVerse v1 是本地单人账本:没有同步状态、没有远程账本、没有上传中状态。
    final params = (
      ledgerId: ledger.id,
      month: DateTime(DateTime.now().year, DateTime.now().month)
    );
    final totals = ref.watch(monthlyTotalsProvider(params)).valueOrNull;
    final hidden = ref.watch(hideAmountsProvider);
    String money(double value) =>
        hidden ? '••••' : formatBalanceFull(value, ledger.currency);
    return BeeLedgerCard(
      name: translateLedgerName(context, ledger.name),
      subtitle:
          '${ledger.currency} · ${l10n.ledgersRecords('${ledger.transactionCount}')}'
          '${ledger.isShared ? ' · ${ledger.memberCount}' : ''}',
      icon: BeeLineIcon(ledger.isShared ? 'Users' : 'BookOpen', size: 21),
      current: selected,
      currentLabel: l10n.commonCurrent,
      expenseLabel: l10n.v4HomeMonthExpense,
      incomeLabel: l10n.v4HomeMonthIncome,
      expense: totals == null ? '—' : money(totals.$2),
      income: totals == null ? '—' : money(totals.$1),
      onSelect: onTap ?? () {},
      onMenu: onMore ?? onLongPress ?? () {},
      footer: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              l10n.ledgersBalance(money(ledger.balance)),
              style: TextStyle(
                  fontSize: 12, color: BeeTokens.textSecondary(context)))),
      actions: [
        if (onBudget != null)
          BeeButton(
              label: l10n.budgetManagement,
              icon: const BeeLineIcon('ChartPie', size: 14),
              kind: BeeButtonKind.secondary,
              compact: true,
              onPressed: onBudget),
        if (onMembers != null)
          BeeButton(
              label: l10n.sharedMembersPageTitle,
              icon: const BeeLineIcon('Users', size: 14),
              kind: BeeButtonKind.secondary,
              compact: true,
              onPressed: onMembers)
        else if (onEdit != null)
          BeeButton(
              label: l10n.ledgersEdit,
              icon: const BeeLineIcon('Settings2', size: 14),
              kind: BeeButtonKind.secondary,
              compact: true,
              onPressed: onEdit),
      ],
    );
  }
}
