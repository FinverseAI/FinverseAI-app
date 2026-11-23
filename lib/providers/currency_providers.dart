import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/currency/rate_math.dart';
import 'database_providers.dart';
import 'statistics_providers.dart';

/// 多币种 MVP 的 provider 层(.docs/multi-currency/02-tech-design-app.md §五/§六)。
/// 主币种链照 displayName(theme_providers.dart:275-312)同款。

/// 用户主币种(大写 ISO code)。FinVerse v1 是 INR-only:本地真值存 prefs
/// 'baseCurrency',默认 INR,不再向任何云端推送。
final baseCurrencyProvider = StateProvider<String>((ref) => 'INR');

/// 汇率数据变更信号:拉取成功 / 手动编辑后 bump,触发 effectiveRates 重算。
final rateRefreshTickProvider = StateProvider<int>((ref) => 0);

/// 启动初始化:读 prefs;主币种未设置时按
/// ① Welcome 选币(selected_currency) → ② 当前账本币种 → ③ INR 初始化。
final baseCurrencyInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var saved = prefs.getString('baseCurrency');
  if (saved == null || saved.isEmpty) {
    saved = prefs.getString('selected_currency');
    if (saved == null || saved.isEmpty) {
      saved = ref.read(currentLedgerProvider).valueOrNull?.currency;
    }
    if (saved == null || saved.isEmpty) saved = 'INR';
    await prefs.setString('baseCurrency', saved);
  }
  ref.read(baseCurrencyProvider.notifier).state = saved.toUpperCase();

  ref.listen<String>(baseCurrencyProvider, (prev, next) async {
    await prefs.setString('baseCurrency', next);
  });
});

/// 使用中币种 ∪ {主币种}(大写)。watch statsRefresh 跟随账户增删改。
final usedCurrenciesProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(statsRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  final used = await repo.getUsedCurrencies();
  used.add(ref.watch(baseCurrencyProvider).toUpperCase());
  return used;
});

/// 多币种态总闸(README D6):使用中币种 ≥2 即恒为折算态,与 Web 端对齐。
/// 原「按主币种折算」开关已下线(默认折算),不再有「非折算多币种」态。
final multiCurrencyActiveProvider = Provider<bool>((ref) {
  final used = ref.watch(usedCurrenciesProvider).valueOrNull;
  return used != null && used.length >= 2;
});

/// 有效汇率:手动 > 最新自动;缺失显式缺失(D5)。
final effectiveRatesProvider =
    FutureProvider<Map<String, EffectiveRate>>((ref) async {
  ref.watch(rateRefreshTickProvider);
  ref.watch(statsRefreshProvider); // 同步 pull 应用 override 后随全局刷新信号重算
  final base = ref.watch(baseCurrencyProvider).toUpperCase();
  final repo = ref.watch(repositoryProvider);
  final autos = await repo.getLatestAutoRates(base);
  final overrides = await repo.getOverrides(base);
  return mergeEffectiveRates(
    autoRates: [
      for (final r in autos)
        (quote: r.quoteCurrency, rate: r.rate, rateDate: r.rateDate)
    ],
    overrides: [
      for (final o in overrides) (quote: o.quoteCurrency, rate: o.rate)
    ],
  );
});

/// 币种选择弹窗的展示汇率:1 该币种 ≈ ? base。拉一次全量(fawaz base→quote
/// 全量返回),手动 override 优先。仅展示用,不落库。family key = base(大写)。
/// 值 = 「1 quote 币种 = value base」(便于 UI 显示 1 JPY ≈ 0.048 CNY)。
final currencyPickerRatesProvider =
    FutureProvider.family<Map<String, double>, String>((ref, base) async {
  ref.watch(rateRefreshTickProvider);
  final baseUp = base.toUpperCase();
  final repo = ref.watch(repositoryProvider);
  final out = <String, double>{};
  // FinVerse v1 是 INR-only:不再拉取公网汇率,仅用本地手动 override 覆盖。
  // 手动 override 覆盖(1 quote = rate base,直接用)
  try {
    for (final o in await repo.getOverrides(baseUp)) {
      final r = double.tryParse(o.rate);
      if (r != null && r > 0) out[o.quoteCurrency.toUpperCase()] = r;
    }
  } catch (_) {}
  return out;
});

/// 当前账本本位币(ISO 大写)。`ledger.currency` 的语义化别名——交易级多币种后
/// 它的语义是「账本统计折算的目标币种」(.docs/multi-currency-ledger L1)。
final currentLedgerCurrencyProvider = Provider<String>((ref) {
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  final c = ledger?.currency;
  return (c == null || c.isEmpty) ? 'INR' : c.toUpperCase();
});

/// 以**账本本位币**为 base 的有效汇率(账户/交易币种 → 账本本位币)。
/// 结构同 [effectiveRatesProvider],仅 base 从用户主币种换成账本本位币;
/// 两者默认相同(新账本本位币默认=主币种),不同账本切换时自动重算。
/// 记账折算(computeNativeAmount)用这组。
final effectiveRatesForLedgerProvider =
    FutureProvider<Map<String, EffectiveRate>>((ref) async {
  ref.watch(rateRefreshTickProvider);
  ref.watch(statsRefreshProvider);
  final base = ref.watch(currentLedgerCurrencyProvider);
  final repo = ref.watch(repositoryProvider);
  final autos = await repo.getLatestAutoRates(base);
  final overrides = await repo.getOverrides(base);
  return mergeEffectiveRates(
    autoRates: [
      for (final r in autos)
        (quote: r.quoteCurrency, rate: r.rate, rateDate: r.rateDate)
    ],
    overrides: [
      for (final o in overrides) (quote: o.quoteCurrency, rate: o.rate)
    ],
  );
});

/// 当前账本「未折算外币交易」条数(L11 检测):>0 时统计页显示补折算横幅。
/// watch statsRefresh(重算完成/交易变动后重查)。
final ledgerUnconvertedForeignTxCountProvider = FutureProvider<int>((ref) async {
  ref.watch(statsRefreshProvider);
  ref.watch(rateRefreshTickProvider);
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  if (ledger == null) return 0;
  final repo = ref.watch(repositoryProvider);
  return repo.countUnconvertedForeignTx(ledger.id);
});

/// 当前账本外币交易条数(含已折算):>0 时账本统计页显示折算脚注(01 §五)。
final ledgerForeignTxCountProvider = FutureProvider<int>((ref) async {
  ref.watch(statsRefreshProvider);
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  if (ledger == null) return 0;
  final repo = ref.watch(repositoryProvider);
  return repo.countForeignCurrencyTx(ledger.id);
});

/// 资产页折算结果。
final convertedNetWorthProvider =
    FutureProvider<ConvertedNetWorth>((ref) async {
  final breakdown = await ref.watch(netWorthBreakdownByCurrencyProvider.future);
  final rates = await ref.watch(effectiveRatesProvider.future);
  final base = ref.watch(baseCurrencyProvider).toUpperCase();
  return computeConvertedNetWorth(breakdown: breakdown, rates: rates, base: base);
});

/// 折算后的资产构成:每 (type, currency) 原币余额 × 汇率 → 按 type 聚合(主币种值)。
/// 缺汇率的币种整条剔除(绝不按 1.0,与净资产/分组小计一致,README D5)。
/// 多币种折算态喂给 [AssetCompositionChart](入参类型与 [assetCompositionProvider] 相同)。
final convertedAssetCompositionProvider =
    FutureProvider<List<({String type, double totalBalance})>>((ref) async {
  final rates = await ref.watch(effectiveRatesProvider.future);
  final base = ref.watch(baseCurrencyProvider).toUpperCase();
  ref.watch(statsRefreshProvider);
  ref.watch(rateRefreshTickProvider);
  final repo = ref.watch(repositoryProvider);
  final rows = await repo.getAssetCompositionByTypeAndCurrency();

  final byType = <String, double>{};
  for (final r in rows) {
    final code = r.currency.toUpperCase();
    double? rate;
    if (code == base) {
      rate = 1.0;
    } else {
      final eff = rates[code];
      if (eff != null) rate = double.tryParse(eff.rate);
    }
    if (rate == null || rate <= 0) continue; // 缺汇率剔除
    byType.update(r.type, (v) => v + r.totalBalance * rate!,
        ifAbsent: () => r.totalBalance * rate!);
  }
  return byType.entries
      .map((e) => (type: e.key, totalBalance: e.value))
      .toList();
});

/// 拉取协调:FinVerse v1 是 INR-only,不再拉取汇率(无 server 源、无公网链)。
/// 保留入口供现有调用方编译;汇率拉取随 FinVerse 后端 / FX 层一起回来。
///
/// Ref 版入口当前无调用方,保留给后台/provider 语境的未来调用
/// (如周期刷新、启动预拉);UI 层用 [refreshExchangeRatesFromUi]。
Future<bool> refreshExchangeRates(Ref ref,
        {bool force = false, Set<String>? extraQuotes}) async =>
    false;

/// UI 层薄封装:`WidgetRef` 与 `Ref` 的 read 能力等价,直接转发到同一实现。
/// ConsumerState 里只有 `WidgetRef`,无法 cast 成 `Ref`,故单开此入口。
Future<bool> refreshExchangeRatesFromUi(WidgetRef ref,
        {bool force = false, Set<String>? extraQuotes}) async =>
    false;
