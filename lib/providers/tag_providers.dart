import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import 'database_providers.dart';

/// 标签列表刷新触发器
final tagListRefreshProvider = StateProvider<int>((ref) => 0);

/// 当前账本是否允许在标签选择器中创建标签。
///
/// 标签仍是 user-scoped；共享账本的 Editor 只能使用 Owner 同步下来的标签，
/// 因此不能在共享账本记账流程里创建自己的标签。
final canCreateTagForCurrentLedgerProvider = Provider<bool>((ref) {
  // 切换账本触发 reload 时 Riverpod 会保留 previous value；权限判断不能沿用
  // 上一个个人/Owner 账本，否则进入 Editor 账本的短窗口仍会暴露创建入口。
  final ledger = ref.watch(currentLedgerProvider).unwrapPrevious().valueOrNull;
  if (ledger == null) return false;
  return !ledger.isShared || ledger.myRole == 'owner';
});

/// 所有标签列表 Provider（响应式）
final allTagsStreamProvider = StreamProvider<List<Tag>>((ref) {
  ref.watch(tagListRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllTags();
});

/// 所有标签列表 Provider（Future版本）
final allTagsProvider = FutureProvider<List<Tag>>((ref) async {
  ref.watch(tagListRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  return await repo.getAllTags();
});

/// 标签列表按当前账本过滤。FinVerse v1 是单人账本:直接返回全部标签,
/// 不再按共享账本的 Owner/Editor 角色做 mirror 过滤。
final tagsForCurrentLedgerProvider = FutureProvider<List<Tag>>((ref) async {
  ref.watch(tagListRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  return await repo.getAllTags();
});

/// 标签列表带统计信息 Provider（响应式）
/// 返回每个标签及其关联的交易数量
final tagsWithStatsProvider = StreamProvider<List<({Tag tag, int transactionCount})>>((ref) {
  ref.watch(tagListRefreshProvider);
  // §7 决策 v25:Owner 资源不 mirror 主表,管理页直接读主 Tags。
  final repo = ref.watch(repositoryProvider);
  return repo.watchTagsWithStats();
});

/// 交易关联的标签 Provider
/// 根据交易ID获取该交易的所有标签
final transactionTagsProvider = StreamProvider.family<List<Tag>, int>((ref, transactionId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchTagsForTransaction(transactionId);
});

/// 标签详情 Provider（响应式）
final tagDetailProvider = StreamProvider.family<Tag?, int>((ref, tagId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchTag(tagId);
});

/// 标签统计信息 Provider
/// 返回标签的交易数、总支出、总收入
final tagStatsProvider = FutureProvider.family<({int count, double expense, double income}), int>((ref, tagId) async {
  ref.watch(tagListRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  return await repo.getTagStats(tagId);
});

/// 标签下的交易列表 Provider（响应式）
final tagTransactionsProvider = StreamProvider.family<List<Transaction>, int>((ref, tagId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchTransactionsByTag(tagId);
});

/// 批量获取多个交易的标签 Provider
/// 用于交易列表优化，避免 N+1 查询
final batchTransactionTagsProvider = FutureProvider.family<Map<int, List<Tag>>, List<int>>((ref, transactionIds) async {
  if (transactionIds.isEmpty) return {};
  final repo = ref.watch(repositoryProvider);
  return await repo.getTagsForTransactions(transactionIds);
});

/// 最近使用的标签 Provider(按当前账本)。FinVerse v1 是单人账本:直接返回
/// 最近使用的标签,不再走共享账本 Editor 的 TransactionTagOverrides 分支。
final recentTagsForCurrentLedgerProvider = FutureProvider<List<Tag>>((ref) async {
  ref.watch(tagListRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  return await repo.getRecentlyUsedTags(limit: 10);
});

/// 最近使用的标签 Provider
/// 用于标签选择器快速选择
final recentlyUsedTagsProvider = FutureProvider<List<Tag>>((ref) async {
  ref.watch(tagListRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  return await repo.getRecentlyUsedTags(limit: 10);
});

/// 标签搜索结果 Provider
/// 根据关键字搜索标签
final tagSearchResultsProvider = FutureProvider.family<List<Tag>, String>((ref, keyword) async {
  final allTags = await ref.watch(allTagsProvider.future);

  if (keyword.isEmpty) {
    return allTags;
  }

  final lowerKeyword = keyword.toLowerCase();
  return allTags.where((tag) =>
    tag.name.toLowerCase().contains(lowerKeyword)
  ).toList();
});

/// 检查标签名是否重复 Provider
final isTagNameDuplicateProvider = FutureProvider.family<bool, ({String name, int? excludeId})>((ref, params) async {
  final repo = ref.watch(repositoryProvider);
  return await repo.isTagNameDuplicate(name: params.name, excludeId: params.excludeId);
});
