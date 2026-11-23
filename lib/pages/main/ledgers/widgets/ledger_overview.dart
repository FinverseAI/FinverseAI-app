part of '../../ledgers_page_new.dart';

mixin _LedgerOverview on ConsumerState<LedgersPageNew>, _LedgerActions {
  // FinVerse v1 是本地单人账本:只有本地账本列表,没有云端/共享账本分区。
  Widget _buildProgressiveList(
      BuildContext context,
      WidgetRef ref,
      int? currentId,
      AsyncValue<List<LedgerDisplayItem>> localAsync) {
    final l = AppLocalizations.of(context);
    final local = localAsync.valueOrNull ?? [];
    if (localAsync.isLoading && local.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (localAsync.hasError && local.isEmpty) {
      return SingleChildScrollView(
          padding: const EdgeInsets.all(17),
          child: BeeStatus(
              tone: BeeTone.error,
              label: l.commonError,
              detail: '${localAsync.error}',
              action: BeeButton(
                  label: l.helpCenterRetry,
                  onPressed: () => ref.invalidate(localLedgersProvider))));
    }
    final empty = local.isEmpty;
    return ListView(
        padding: const EdgeInsets.fromLTRB(17, 8, 17, 24),
        children: [
          if (empty) ...[
            BeeEmptyState(
                title: l.ledgersEmpty,
                icon: const BeeLineIcon('BookOpen', size: 32)),
            const SizedBox(height: 16),
          ],
          if (local.isNotEmpty) ...[
            _ledgerSection(l.ledgersLocal, '${local.length}'),
            ...local.map((ledger) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LedgerCard(
                    ledger: ledger,
                    selected: ledger.id == currentId,
                    onTap: () => _handleLocalLedgerTap(ledger),
                    onLongPress: () => _showLocalLedgerActions(context, ledger),
                    onMore: () => _showLocalLedgerActions(context, ledger),
                    onBudget: () => _showLocalLedgerActions(context, ledger,
                        initialAction: 'budget'),
                    onEdit: ledger.myRole == 'owner'
                        ? () => _showLocalLedgerActions(context, ledger,
                            initialAction: 'edit')
                        : null))),
          ],
          BeeButton(
              label: l.ledgersNew,
              icon: const BeeLineIcon('Plus', size: 18),
              onPressed: () => _showCreateLedgerDialog(context)),
        ]);
  }

  Widget _ledgerSection(String title, String? count, {Widget? action}) =>
      Padding(
          padding: const EdgeInsets.fromLTRB(3, 8, 3, 12),
          child: Row(children: [
            Expanded(
                child: Text('$title${count == null ? '' : ' · $count'}',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor))),
            if (action != null) action,
          ]));
}
