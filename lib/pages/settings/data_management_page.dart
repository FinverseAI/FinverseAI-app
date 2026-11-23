import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../l10n/app_localizations.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'attachments/bindings/attachment_transfer_actions.dart';
import '../data/export_page.dart';
import '../category/category_manage_page.dart';
import '../category/category_migration_page.dart';
import '../tag/tag_manage_page.dart';
import 'storage_management_page.dart';

class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});
  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage>
    with AttachmentTransferActions<DataManagementPage> {
  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget menu(String title, String icon, Widget page, [String? subtitle]) =>
        BeeMenuRow(
            title: title,
            subtitle: subtitle,
            leading: BeeLineIcon(icon, size: 20),
            onTap: () => open(page));
    Widget section(String title, List<Widget> children) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(2, 20, 2, 9),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).hintColor))),
          BeeSurface(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Column(children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const BeeDivider(inset: 12, height: .6),
                  children[i]
                ]
              ]))
        ]);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.dataManagementPageTitle, leading: const BackButton()),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 24),
              children: [
            Text(l.dataManagementAttachmentHint,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Theme.of(context).hintColor)),
            section(l.v4DataBills, [
              menu(l.mineExport, 'FileDown', const ExportPage())
            ]),
            section(l.v4DataCategories, [
              menu(l.mineCategoryManagement, 'Shapes',
                  const CategoryManagePage(), l.mineCategoryManagementSubtitle),
              menu(
                  l.mineCategoryMigration,
                  'ArrowLeftRight',
                  const CategoryMigrationPage(),
                  l.mineCategoryMigrationSubtitle),
              menu(l.tagManageTitle, 'Tags', const TagManagePage(),
                  l.tagManageSubtitle)
            ]),
            section(l.v4DataConfiguration, [
              menu(l.storageManagementTitle, 'HardDrive',
                  const StorageManagementPage(), l.storageManagementSubtitle),
            ]),
            section(l.v4DataAttachments, [
              BeeMenuRow(
                  title: l.attachmentPreview,
                  leading: const BeeLineIcon('Eye', size: 20),
                  onTap: isExporting ? null : previewExportAttachments),
              BeeFileTransferStatus(
                  title: l.attachmentExportTitle,
                  subtitle: l.attachmentExportSubtitle,
                  leading: const BeeLineIcon('Archive', size: 20),
                  state: isExporting
                      ? BeeFileTaskState.running
                      : BeeFileTaskState.ready,
                  onTap: exportAttachmentsAction,
                  onPreview: isExporting ? null : previewExportAttachments,
                  previewLabel: l.attachmentPreview,
                  progress:
                      exportTotal == 0 ? null : exportProgress / exportTotal,
                  progressLabel:
                      exportAttachmentCount > 0 || exportIconCount > 0
                          ? l.attachmentExportProgressDetail(
                              exportAttachmentCount,
                              exportIconCount,
                              exportProgress,
                              exportTotal)
                          : l.attachmentExportProgress(
                              exportProgress, exportTotal)),
              BeeFileTransferStatus(
                  title: l.attachmentImportTitle,
                  subtitle: l.attachmentImportSubtitle,
                  leading: const BeeLineIcon('FolderInput', size: 20),
                  state: isImporting
                      ? BeeFileTaskState.running
                      : BeeFileTaskState.ready,
                  onTap: selectAttachmentImportFile,
                  progress:
                      importTotal == 0 ? null : importProgress / importTotal,
                  progressLabel:
                      l.attachmentImportProgress(importProgress, importTotal))
            ]),
          ]))
    ]));
  }
}
