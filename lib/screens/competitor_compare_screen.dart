import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';
import '../services/seo_scraper_service.dart';
import '../services/site_files_checker.dart';
import '../utils/url_validator.dart';
import '../widgets/app_widgets.dart';
import '../widgets/audit_cards.dart';
import 'legal_pages.dart';

class CompetitorCompareScreen extends StatefulWidget {
  const CompetitorCompareScreen({
    super.key,
    required this.result,
    required this.onGoToAudit,
  });
  final SeoAuditResult? result;
  final VoidCallback onGoToAudit;
  @override
  State<CompetitorCompareScreen> createState() =>
      _CompetitorCompareScreenState();
}

class _CompetitorCompareScreenState extends State<CompetitorCompareScreen> {
  static const _audit = SeoAuditService();
  final _yourUrl = TextEditingController();
  final _competitorUrl = TextEditingController();
  final _files = SiteFilesChecker();
  SeoAuditResult? _your, _competitor;
  SiteFilesReport? _yourFiles, _competitorFiles;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.result != null) _yourUrl.text = widget.result!.url;
  }

  @override
  void didUpdateWidget(covariant CompetitorCompareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result?.url != widget.result?.url) {
      _your = null;
      _competitor = null;
      _yourFiles = null;
      _competitorFiles = null;
      if (widget.result != null) _yourUrl.text = widget.result!.url;
    }
  }

  @override
  void dispose() {
    _yourUrl.dispose();
    _competitorUrl.dispose();
    _files.close();
    super.dispose();
  }

  Future<void> _compare() async {
    if (_loading) return;
    final a = UrlValidator.validate(_yourUrl.text),
        b = UrlValidator.validate(_competitorUrl.text);
    if (!a.isValid || !b.isValid) {
      setState(
        () => _error = !a.isValid
            ? 'Your website: ${a.message}'
            : 'Competitor: ${b.message}',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pages = await Future.wait([
        _audit.audit(a.uri!.toString()),
        _audit.audit(b.uri!.toString()),
      ]);
      final files = await Future.wait([
        _files.check(a.uri!),
        _files.check(b.uri!),
      ]);
      if (!mounted) return;
      setState(() {
        _your = pages[0];
        _competitor = pages[1];
        _yourFiles = files[0];
        _competitorFiles = files[1];
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is SeoScrapeException ? e.userMessage : 'Could not compare these websites. Check both URLs and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: const [ThemeModeToggle(), LegalMenuButton()],
      title: const BrandTitle(
        title: 'Competitor Compare',
        icon: Icons.compare_arrows_rounded,
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Head-to-head comparison',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _yourUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Your Website URL',
                    hintText: 'https://example.com',
                    prefixIcon: Icon(Icons.public),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _competitorUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Competitor URL',
                    hintText: 'https://competitor.com',
                    prefixIcon: Icon(Icons.travel_explore),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _compare,
                  icon: const Icon(Icons.compare_arrows),
                  label: Text(_loading ? 'Comparing…' : 'Compare Websites'),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ErrorCard(message: _error!),
            ),
          if (_your != null &&
              _competitor != null &&
              _yourFiles != null &&
              _competitorFiles != null) ...[
            const SizedBox(height: 16),
            _Results(
              y: _your!,
              c: _competitor!,
              yf: _yourFiles!,
              cf: _competitorFiles!,
            ),
          ],
        ],
      ),
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results({
    required this.y,
    required this.c,
    required this.yf,
    required this.cf,
  });
  final SeoAuditResult y, c;
  final SiteFilesReport yf, cf;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Comparison results',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                Uri.tryParse(y.url)?.host ?? y.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                Uri.tryParse(c.url)?.host ?? c.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CompareRow(
          context,
          'Overall SEO score',
          y.score,
          c.score,
          max: 100,
          suffix: '/100',
        ),
        _CompareRow(
          context,
          'Title length',
          y.title?.length ?? 0,
          c.title?.length ?? 0,
          max: 60,
          suffix: ' chars',
        ),
        _CompareRow(
          context,
          'Description length',
          y.description?.length ?? 0,
          c.description?.length ?? 0,
          max: 160,
          suffix: ' chars',
        ),
        _CompareRow(
          context,
          'H1 headings',
          y.h1Count,
          c.h1Count,
          max: _max(y.h1Count, c.h1Count),
        ),
        _CompareRow(
          context,
          'H2 headings',
          y.h2Count,
          c.h2Count,
          max: _max(y.h2Count, c.h2Count),
        ),
        _CompareRow(
          context,
          'H3 headings',
          y.h3Count,
          c.h3Count,
          max: _max(y.h3Count, c.h3Count),
        ),
        _CompareRow(
          context,
          'Images / missing alt',
          y.imageReport.totalImages,
          c.imageReport.totalImages,
          detailA: '${y.imageReport.missingAltCount} missing alt',
          detailB: '${c.imageReport.missingAltCount} missing alt',
          max: _max(y.imageReport.totalImages, c.imageReport.totalImages),
        ),
        _CompareRow(
          context,
          'Schema markup',
          y.hasSchema ? 1 : 0,
          c.hasSchema ? 1 : 0,
          labelA: y.hasSchema ? 'Present' : 'Missing',
          labelB: c.hasSchema ? 'Present' : 'Missing',
          max: 1,
        ),
        _CompareRow(
          context,
          'Robots.txt',
          yf.robots.passed ? 1 : 0,
          cf.robots.passed ? 1 : 0,
          labelA: yf.robots.passed ? 'Found' : 'Missing',
          labelB: cf.robots.passed ? 'Found' : 'Missing',
          max: 1,
        ),
        _CompareRow(
          context,
          'Sitemap.xml',
          yf.sitemap.passed ? 1 : 0,
          cf.sitemap.passed ? 1 : 0,
          labelA: yf.sitemap.passed ? 'Found' : 'Missing',
          labelB: cf.sitemap.passed ? 'Found' : 'Missing',
          max: 1,
        ),
      ],
    ),
  );
  static int _max(int a, int b) => a > b
      ? a
      : b == 0
      ? 1
      : b;
}

class _CompareRow extends StatelessWidget {
  const _CompareRow(
    BuildContext context,
    this.label,
    this.a,
    this.b, {
    required this.max,
    this.suffix = '',
    this.labelA,
    this.labelB,
    this.detailA,
    this.detailB,
  });
  final String label;
  final int a, b, max;
  final String suffix;
  final String? labelA, labelB, detailA, detailB;
  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.primary;
    final aWins = a > b, bWins = b > a;
    final av = labelA ?? '$a$suffix', bv = labelB ?? '$b$suffix';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  av,
                  style: TextStyle(
                    color: aWins ? green : null,
                    fontWeight: aWins ? FontWeight.bold : null,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  bv,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: bWins ? green : null,
                    fontWeight: bWins ? FontWeight.bold : null,
                  ),
                ),
              ),
            ],
          ),
          if (detailA != null || detailB != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    detailA ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    detailB ?? '',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _CompareBar(
                  value: (a / max).clamp(0, 1).toDouble(),
                  color: aWins ? green : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompareBar(
                  value: (b / max).clamp(0, 1).toDouble(),
                  color: bWins ? green : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bar that eases to its new value instead of snapping when results load.
class _CompareBar extends StatelessWidget {
  const _CompareBar({required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => LinearProgressIndicator(
        value: animated,
        color: color,
        minHeight: 5,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
