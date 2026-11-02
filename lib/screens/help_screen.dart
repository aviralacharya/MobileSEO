import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';
import '../widgets/support_card.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _query = '';
  static const _faqs = [
    (
      'How do I share a page from my browser?',
      'On Android, open a page in your browser, choose Share and select MobileSEO (sometimes under More). A single web URL is placed in the audit field. Tap Run SEO Audit when ready. If several URLs were shared, choose one. An active audit continues until you choose Audit shared page. Other platforms can use the URL field directly.',
    ),
    (
      'How do the guided audit and fix guides work?',
      'The Dashboard guides you from a page audit to one useful fix and a recheck. Open View fix or Evidence & fix, then choose WordPress, Shopify or HTML. WordPress metadata steps use Yoast SEO; other plugins have similar fields. Publish changes in your website editor, then use the guide’s recheck button. MobileSEO does not edit your website. You can hide the hints and turn them on again under Settings / Audit guidance.',
    ),
    (
      'How is the SEO score calculated?',
      'The measured score is the percentage of six core checks that pass: title, description, H1, H2, image alt text and schema presence. Extended indexing, viewport and social checks appear in the issue list but do not change this score. This is an on-page checklist, not a prediction of search rankings.',
    ),
    (
      'What do To do, In progress and Verified mean?',
      'Start a fix to save it as In progress in the page’s project. Publish the change on your website, then re-audit the same page. A finding is Verified only when it failed in the previous snapshot and passes in the later one. An older saved snapshot is read-only for fix tracking.',
    ),
    (
      'Why is the projected score different?',
      'Projected score shows what the core score could be if your selected in-progress core checks passed. Your measured score stays tied to the actual audit. Extended diagnostics do not add projected points.',
    ),
    (
      'How do before-and-after comparisons work?',
      'Open Projects, then Audit history, and select two snapshots of exactly the same page. URL fragments are ignored, but schemes, ports, paths and query parameters identify different pages. The earlier snapshot is always Before. You can see resolved, new and remaining issues.',
    ),
    (
      'Where do PageSpeed results open?',
      'Tap Run PageSpeed in Technical & Links to open Google PageSpeed Insights in your default browser with the audited URL already filled in and Mobile selected. Google runs the speed test and shows available Core Web Vitals there. Return to MobileSEO to continue your audit. If the browser cannot open, copy the PageSpeed link from the card.',
    ),
    (
      'Why can’t a website be audited?',
      'Check the URL and your connection. Some websites reject automated requests, require authentication or render important content only in JavaScript. MobileSEO analyzes the returned HTML. Browser builds are also subject to the website’s CORS policy; native Android and iOS builds do not have that browser restriction.',
    ),
    (
      'Where is my data stored?',
      'Projects, in-progress fixes, preferences and up to 100 audit snapshots are stored on this device. There is no account or cloud sync. Settings lets you clear history or PageSpeed data saved by earlier in-app checks. New PageSpeed reports open in your browser. Removing a project also removes its tracked fixes, but keeps its audit history.',
    ),
    (
      'Can I try the app without a website?',
      'Choose Explore sample audit on the Dashboard or in Tools. The bundled example and its platform-specific fix guides work offline and stay out of your real history. Sample results do not change or verify fixes. Sample fix selections reset when you load the example again. Choose Try your own page to start a real audit.',
    ),
  ];
  static const _glossary = [
    (
      'Canonical URL',
      'The preferred URL declared by a page. It helps search engines consolidate duplicate versions, but is a hint rather than a guarantee.',
    ),
    (
      'Core Web Vitals',
      'LCP measures loading, CLS measures visual stability and INP measures responsiveness. Field metrics reflect the 75th percentile of real visitors; lab metrics come from a controlled Lighthouse run.',
    ),
    (
      'H1 / H2',
      'HTML headings describe the page topic and its sections. Use a clear hierarchy that makes sense for people reading the page.',
    ),
    (
      'JSON-LD / Schema',
      'Structured data describes entities and content in a machine-readable format. Valid JSON syntax and a detected type do not guarantee rich-result eligibility.',
    ),
    (
      'Meta description',
      'A short summary that search engines may use in a result snippet. Search engines can choose different text depending on the query.',
    ),
    (
      'Noindex / Nofollow',
      'Noindex requests that a page not be indexed. Nofollow concerns following links and does not by itself prevent the page from being indexed.',
    ),
    (
      'Open Graph',
      'Metadata that controls the title, description and image suggested when a page is shared on social platforms.',
    ),
    (
      'Robots.txt / Sitemap',
      'Robots.txt provides crawler instructions. A sitemap lists discoverable URLs. Checking the root files does not crawl the entire website or prove that a page is indexed.',
    ),
    (
      'LLMs.txt / AI crawler access',
      'Optional guidance files and robots rules used by some AI-related tools. Their presence is not a ranking signal or a guarantee of inclusion in AI answers.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BrandTitle(title: 'Help & SEO glossary')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              TextField(
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  labelText: 'Search help',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 20),
              _section('Frequently asked questions', _faqs),
              const SizedBox(height: 16),
              _section('SEO glossary', _glossary),
              const SizedBox(height: 16),
              const SupportCard(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _section(String title, List<(String, String)> items) {
    final matches = items
        .where((item) => '${item.$1} ${item.$2}'.toLowerCase().contains(_query))
        .toList();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (matches.isEmpty) const Text('No matching topics.'),
          for (final item in matches)
            ExpansionTile(
              key: PageStorageKey(item.$1),
              tilePadding: EdgeInsets.zero,
              title: Text(item.$1),
              childrenPadding: const EdgeInsets.only(bottom: 16),
              children: [
                Align(alignment: Alignment.centerLeft, child: Text(item.$2)),
              ],
            ),
        ],
      ),
    );
  }
}
