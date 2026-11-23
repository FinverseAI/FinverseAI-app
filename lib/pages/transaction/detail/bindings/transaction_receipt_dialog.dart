import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/db.dart';
import '../../../../l10n/app_localizations.dart';

/// 交易小票(收据海报)对话框 — 已随分享海报功能一起剥离。
///
/// The receipt poster this dialog rendered (`TransactionReceipt` +
/// `BeeReceiptComposer` + the share/save export) depended on the removed
/// share-poster service and the deleted receipt components, so the dialog
/// can no longer render. The entry points that opened it were removed with
/// it (transaction detail actions, transaction list actions). This stub
/// keeps the public `open` entry point compiling for any missed caller and
/// tells the user the receipt is unavailable in FinVerse v1 instead of
/// crashing.
class TransactionReceiptDialog extends StatelessWidget {
  const TransactionReceiptDialog({super.key});

  static Future<void> open(
      BuildContext context, WidgetRef ref, Transaction transaction) async {
    if (!context.mounted) return;
    showBeeToast(
        context, AppLocalizations.of(context).transactionReceiptUnavailable,
        tone: BeeTone.warning);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
