import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';
import '../widgets/support_card.dart';

class LegalMenuButton extends StatelessWidget {
  const LegalMenuButton({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: 'Legal information',
    icon: const Icon(Icons.more_vert_rounded),
    onSelected: (index) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPagesScreen(initialPage: index),
      ),
    ),
    itemBuilder: (context) => const [
      PopupMenuItem(value: 0, child: Text('Privacy Policy')),
      PopupMenuItem(value: 1, child: Text('Terms & Conditions')),
    ],
  );
}

class LegalPagesScreen extends StatefulWidget {
  const LegalPagesScreen({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  State<LegalPagesScreen> createState() => _LegalPagesScreenState();
}

class _LegalPagesScreenState extends State<LegalPagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialPage.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const BrandTitle(title: 'Legal information'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Privacy Policy'),
          Tab(text: 'Terms & Conditions'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        _LegalDocument(
          title: 'Privacy Policy',
          intro: 'This policy explains how MobileSEO handles information when you use the app. Last updated November 1, 2026.',
          sections: const [
            _LegalSection(
              'Information you provide',
              'When you run an audit or compare websites, the URLs you enter are used to request and analyze publicly available page content. MobileSEO does not require an account, and the app does not ask for your name or other profile details.',
            ),
            _LegalSection(
              'Links shared from other apps',
              'On Android, you can share text or a page link with MobileSEO. The app extracts web URLs on your device and prepares them for an audit. Receiving a shared link does not start a website request; you choose when to run the audit. Unused shared text is not added to your audit history.',
            ),
            _LegalSection(
              'How audits work',
              'The app requests pages and related public site files directly from your device, then analyzes the returned HTML and response data. Audit results are processed in the app; they are not sent to a MobileSEO account or audit server.',
            ),
            _LegalSection(
              'On-device workspace and preferences',
              'Up to 100 audit snapshots, saved project names and URLs, in-progress fixes, appearance/accessibility preferences, your chosen website platform and guided-audit preference are saved locally on your device. You can remove projects or individual audits in Projects and clear all audit history in Settings & Help. Clearing history removes comparison evidence; project and preference data are kept. Uninstalling the app or clearing its storage may remove this data. Device backup behavior is controlled by your operating system settings.',
            ),
            _LegalSection(
              'Google PageSpeed Insights',
              'When you choose Run PageSpeed, MobileSEO opens Google’s PageSpeed Insights website in your default browser and passes it the audited page URL. Google requests and analyzes that page and handles ordinary request information, including your IP address, under its own privacy policy. New performance reports are viewed in your browser and are not stored by MobileSEO. Reports saved by earlier in-app checks can still be removed in Settings & Help.',
            ),
            _LegalSection(
              'Reports and sharing',
              'PDF and CSV reports are generated on your device and may include the audited URL, findings, dates, optional client and branding names, and notes you enter. If you choose to share or save a report, the receiving app or service handles it under its own privacy policy. MobileSEO does not control what happens after you share a report. Report text you enter is held for the current export screen and is not added to your saved project.',
            ),
            _LegalSection(
              'Network and third-party sites',
              'Requests to audited websites may reveal ordinary network information, such as your IP address, to those websites or their hosting providers. MobileSEO does not control third-party sites, their content, or their privacy practices.',
            ),
            _LegalSection(
              'Children and changes',
              'MobileSEO is a general-purpose utility and is not designed to collect personal information from children. This policy may be updated as the app changes; the latest version will be available in the app.',
            ),
          ],
        ),
        _LegalDocument(
          title: 'Terms & Conditions',
          intro: 'By using MobileSEO, you agree to these terms. Last updated November 1, 2026.',
          sections: const [
            _LegalSection(
              'Use of the app',
              'MobileSEO provides website analysis, previews, comparisons, and reports for informational purposes. You are responsible for the URLs you submit and must have the right or permission to request and analyze them. Use the app in compliance with applicable laws and the target website’s terms.',
            ),
            _LegalSection(
              'Responsible requests',
              'Only audit websites that are publicly accessible or that you are authorized to test. Do not use the app to bypass access controls, disrupt a service, or send requests in a way that violates a website’s rules.',
            ),
            _LegalSection(
              'Informational results',
              'Audit scores and recommendations are automated estimates based on the page response available at the time of the audit. They are not legal, security, accessibility, or search-engine advice, and they do not guarantee rankings, traffic, compliance, or business results.',
            ),
            _LegalSection(
              'Third-party websites and services',
              'The app may request third-party websites, open Google PageSpeed Insights in your browser when requested, and allow you to share PDF or CSV reports with other apps. Those sites and services are operated by others and are subject to their own terms and policies. Availability, quotas and data coverage can vary.',
            ),
            _LegalSection(
              'Availability and changes',
              'Features may change or become unavailable, and results can differ as websites change. MobileSEO is provided on an “as available” basis to the extent permitted by law.',
            ),
            _LegalSection(
              'Contact',
              'Questions about these terms or the app can be sent to the email address below.',
            ),
          ],
        ),
      ],
    ),
  );
}

class _LegalDocument extends StatelessWidget {
  const _LegalDocument({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: PageStorageKey('legal-$title'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(intro, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final section in sections) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.heading, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(section.body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SupportCard(),
      ],
    );
  }
}

class _LegalSection {
  const _LegalSection(this.heading, this.body);

  final String heading;
  final String body;
}
