import 'package:beecount_business_ui/support.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../privacy_policy_page.dart';
import '../../../shared/branding/bee_artwork.dart';
import '../../support/bindings/support_frame.dart';
import '../../support/bindings/support_platform.dart';

class SupportAboutControls extends ConsumerStatefulWidget {
  const SupportAboutControls({super.key});
  @override
  ConsumerState<SupportAboutControls> createState() =>
      _SupportAboutControlsState();
}

class _SupportAboutControlsState extends ConsumerState<SupportAboutControls> {
  String? version;
  bool versionFailed = false;
  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final value = await ref.read(supportPlatformProvider).version();
      if (mounted) setState(() => version = value);
    } catch (_) {
      if (mounted) setState(() => versionFailed = true);
    }
  }

  void _story() {
    final l = AppLocalizations.of(context);
    showDialog(
        context: context,
        builder: (context) => BeeDialog(
                title: Text(l.aboutDeveloperStoryTitle),
                content: SingleChildScrollView(
                    child: Text(l.aboutDeveloperStory,
                        style: TextStyle(
                            height: 1.7,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.commonConfirm))
                ]));
  }

  void _page(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        locale = Localizations.localeOf(context),
        platform = ref.watch(supportPlatformProvider),
        primary = ref.watch(displaySkinPrimaryColorProvider);
    final simplified =
        locale.languageCode == 'zh' && locale.countryCode != 'TW';
    Future<bool> open(String url) => platform.open(Uri.parse(url));
    BeeSupportAction social(String name, String id, String url,
            {String? asset, String icon = 'Globe'}) =>
        BeeSupportAction(
            key: ValueKey('support-social-$id'),
            title: name,
            leading: asset == null
                ? BeeLineIcon(icon,
                    size: 23, color: Theme.of(context).colorScheme.onSurface)
                : SvgPicture.asset(asset,
                    width: 23,
                    height: 23,
                    colorFilter: Theme.of(context).brightness ==
                                Brightness.dark &&
                            {'github', 'douyin'}.contains(id)
                        ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                        : null),
            onTap: () => open(url));
    return SupportFrame(
        title: l.aboutPageTitle,
        subtitle: l.aboutPageSubtitle,
        body: BeePageBody(eager: true, children: [
          BeeSupportBrand(
              logo: BeeIcon(color: primary, size: 80),
              title: l.appName,
              version: version ??
                  (versionFailed ? l.commonError : l.aboutPageLoadingVersion),
              onStory: _story,
              description: l.v4SharePosterOpenSourceBody,
              tag: '${l.appPromoTagOpenSource} · ${l.appPromoTagFree}',
              sourceLabel: l.v4SharePosterOpenSourceAction,
              onSource: () => open('https://github.com/TNT-Likely/BeeCount'),
              socials: [
                social(l.aboutWebsite, 'website',
                    'https://finverseaii.netlify.app'),
                social('GitHub', 'github',
                    'https://github.com/TNT-Likely/BeeCount',
                    asset: 'assets/icons/social/github.svg'),
                if (!simplified)
                  social(l.aboutTelegram, 'telegram', 'https://t.me/beecount',
                      asset: 'assets/icons/social/telegram.svg'),
                social(l.aboutXiaohongshu, 'xiaohongshu',
                    'https://xhslink.com/m/8K1ekg7EFOq',
                    asset: 'assets/icons/social/xiaohongshu.svg'),
                social(l.aboutDouyin, 'douyin',
                    'https://v.douyin.com/YG7tUweYYyQ/',
                    asset: 'assets/icons/social/douyin.svg'),
              ]),
          BeeSupportActions(actions: [
            BeeSupportAction(
                key: const ValueKey('support-development'),
                title: l.aboutSupportDevelopment,
                subtitle: l.aboutSupportDevelopmentSubtitle,
                leading: const BeeLineIcon('Heart'),
                onTap: () => open(locale.languageCode == 'zh'
                    ? 'https://github.com/TNT-Likely/BeeCount/blob/main/docs/donate/README_ZH.md'
                    : 'https://github.com/TNT-Likely/BeeCount/blob/main/docs/donate/README_EN.md')),
            BeeSupportAction(
                key: const ValueKey('support-feedback'),
                title: l.mineFeedback,
                subtitle: l.mineFeedbackSubtitle,
                leading: const BeeLineIcon('MessageSquare'),
                onTap: () =>
                    open('https://github.com/TNT-Likely/BeeCount/issues')),
          ]),
          Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
            TextButton(
                key: const ValueKey('support-privacy'),
                onPressed: () => _page(const PrivacyPolicyPage()),
                child: Text(l.aboutPrivacyPolicy))
          ]),
          if (simplified)
            Text('浙ICP备2025214907号-2A',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor)),
        ]));
  }
}
