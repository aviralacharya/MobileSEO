import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/seo_audit_service.dart';
import '../services/seo_scraper_service.dart';
import '../services/site_files_checker.dart';
import '../utils/url_validator.dart';
import '../widgets/app_widgets.dart';
import '../widgets/audit_cards.dart';

class CompetitorCompareScreen extends StatefulWidget {
  const CompetitorCompareScreen({
    super.key,
    required this.result,
    required this.onGoToAudit,
    this.onBack,
    this.isSample = false,
  });
  final SeoAuditResult? result;
  final VoidCallback onGoToAudit;
  final VoidCallback? onBack;
  final bool isSample;
  @override
  State<CompetitorCompareScreen> createState() =>
      _CompetitorCompareScreenState();
}

class _CompetitorCompareScreenState extends State<CompetitorCompareScreen> {
  static const _audit = SeoAuditService();
  final _yourUrl = TextEditingController();
  final _competitorUrl = TextEditingController();
  http.Client? _client;
  int _generation = 0;
  String _stage = '';
  SeoAuditResult? _your, _competitor;
  SiteFilesReport? _yourFiles, _competitorFiles;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.result != null && !widget.isSample) {
      _yourUrl.text = widget.result!.url;
    }
  }

  @override
  void didUpdateWidget(covariant CompetitorCompareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) {
      _generation++;
      _client?.close();
      _loading = false;
      _error = null;
      _your = null;
      _competitor = null;
      _yourFiles = null;
      _competitorFiles = null;
      if (widget.result != null && !widget.isSample) {
        _yourUrl.text = widget.result!.url;
      }
    }
  }

  @override
  void dispose() {
    _yourUrl.dispose();
    _competitorUrl.dispose();
    _generation++;
    _client?.close();
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
    final generation = ++_generation;
    final client = http.Client();
    _client = client;
    bool current() => mounted && generation == _generation;
    setState(() {
      _loading = true;
      _error = null;
      _your = _competitor = null;
      _yourFiles = _competitorFiles = null;
      _stage = 'Fetching both pages…';
    });
    try {
      final scraper = SeoScraperService(client: client);
      final pages = await Future.wait([
        scraper.fetchDocument(a.uri!.toString()),
        scraper.fetchDocument(b.uri!.toString()),
      ]);
      if (!current()) return;
      setState(() {
        _your = _audit.analyze(pages[0]);
        _competitor = _audit.analyze(pages[1]);
        _stage = 'On-page results ready · Checking site files…';
      });
      final checker = SiteFilesChecker(client: client);
      final files = await Future.wait([
        checker.check(pages[0].uri),
        checker.check(pages[1].uri),
      ]);
      if (!current()) return;
      setState(() {
        _yourFiles = files[0];
        _competitorFiles = files[1];
      });
    } catch (e) {
      if (current()) {
        setState(
          () => _error = e is SeoScrapeException ? e.userMessage : 'Could not compare these websites. Check both URLs and try again.',
        );
      }
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
      if (current()) setState(() => _loading = false);
    }
  }

  void _cancel() {
    _generation++;
    _client?.close();
    _client = null;
    setState(() {
      _loading = false;
      _error = 'Comparison cancelled. You can run it again when ready.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: widget.onBack == null
          ? null
          : BackButton(onPressed: widget.onBack),
      title: const BrandTitle(title: 'Competitor comparison'),
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
                  enabled: !_loading,
                  autocorrect: false,
                  enableSuggestions: false,
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
                  enabled: !_loading,
                  autocorrect: false,
                  enableSuggestions: false,
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (!MediaQuery.disableAnimationsOf(context))
                    const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(_stage),
                  TextButton(
                    onPressed: _cancel,
                    child: const Text('Cancel comparison'),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ErrorCard(message: _error!),
            ),
          if (_your != null && _competitor != null) ...[
            const SizedBox(height: 16),
            _Results(
              y: _your!,
              c: _competitor!,
              yf: _yourFiles,
              cf: _competitorFiles,
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
  final SiteFilesReport? yf, cf;
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
          highlightHigher: true,
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
          highlightHigher: true,
        ),
        if (yf != null && cf != null)
          _CompareRow(
            context,
            'Robots.txt',
            yf!.robots.passed ? 1 : 0,
            cf!.robots.passed ? 1 : 0,
            labelA: yf!.robots.passed ? 'Found' : 'Missing',
            labelB: cf!.robots.passed ? 'Found' : 'Missing',
            max: 1,
            highlightHigher: true,
          ),
        if (yf != null && cf != null)
          _CompareRow(
            context,
            'Sitemap.xml',
            yf!.sitemap.passed ? 1 : 0,
            cf!.sitemap.passed ? 1 : 0,
            labelA: yf!.sitemap.passed ? 'Found' : 'Missing',
            labelB: cf!.sitemap.passed ? 'Found' : 'Missing',
            max: 1,
            highlightHigher: true,
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
    this.highlightHigher = false,
  });
  final String label;
  final int a, b, max;
  final String suffix;
  final String? labelA, labelB, detailA, detailB;
  final bool highlightHigher;
  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.primary;
    final aWins = highlightHigher && a > b, bWins = highlightHigher && b > a;
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
