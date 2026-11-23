// FinVerse v1:单人账本，tx 作者标记为空操作(见下方 TODO)。
// 原实现是共享账本:本地写 tx 后回填创建人 / 编辑人。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// tx 作者标记工具(v1 为空操作，调用方保持不变)。
///
/// 调用场景:
/// - `markCreated`:本地新建 tx 后调
/// - `markEdited`:本地编辑 tx 后调
class TxAuthorService {
  TxAuthorService._();

  static Future<void> markCreated(WidgetRef ref, int txId) async =>
      _markImpl(ref, txId, isCreate: true);

  static Future<void> markEdited(WidgetRef ref, int txId) async =>
      _markImpl(ref, txId, isCreate: false);

  /// Container variant — service-layer / background 路径用(没 WidgetRef)。
  static Future<void> markCreatedC(ProviderContainer c, int txId) async =>
      _markImplC(c, txId, isCreate: true);

  static Future<void> markEditedC(ProviderContainer c, int txId) async =>
      _markImplC(c, txId, isCreate: false);

  // FinVerse v1:单人账本，没有云账号可取作者 id，标记为空操作。
  //
  // TODO(finverse-sync):接后端同步层(同一 Google/Better Auth 账号)后，
  // 在这里取当前用户 id 并调 repo.markTxAuthor。原实现从 BeeCount Cloud
  // 的 auth.currentUser 取 id。
  static Future<void> _markImpl(
    WidgetRef ref,
    int txId, {
    required bool isCreate,
  }) async {}

  static Future<void> _markImplC(
    ProviderContainer c,
    int txId, {
    required bool isCreate,
  }) async {}
}
