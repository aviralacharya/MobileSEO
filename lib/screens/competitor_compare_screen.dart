import 'package:flutter/material.dart';

import '../services/seo_audit_service.dart';
import '../services/seo_scraper_service.dart';
import '../utils/url_validator.dart';
import '../widgets/app_widgets.dart';
import '../widgets/audit_cards.dart';
import '../widgets/score_gauge.dart';

/// Tab 3 of the shell: audit a second URL and compare it with the loaded page.
class CompetitorCompareScreen extends StatefulWidget {
  const CompetitorCompareScreen({
    super.key,
    required this.result,
    required this.onGoToAudit,
  });

  /// The page audited on the dashboard, or `null` before any audit.
  final SeoAuditResult? result;
  final VoidCallback onGoToAudit;

  @override
  State<CompetitorCompareScreen> createState() =>
      _CompetitorCompareScreenState();
}

class _CompetitorCompareScreenState extends State<CompetitorCompareScreen> {
  static const SeoAuditService _auditService = SeoAuditService();

  final TextEditingController _controller = TextEditingController();

  bool _isLoading = false;
  String? _urlError;
  String? _errorMessage;
  SeoAuditResult? _competitor;

  @override
  void didUpdateWidget(CompetitorCompareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new base audit invalidates the comparison.
    if (oldWidget.result?.url != widget.result?.url) {
      _competitor = null;
      _errorMessage = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _compare() async {
    if (_isLoading) return;

    final validation = UrlValidator.validate(_controller.text);
    if (!validation.isValid) {
      setState(() {
        _urlError = validation.message;
        _errorMessage = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _urlError = null;
      _errorMessage = null;
    });

    try {
      final competitor = await _auditService.audit(validation.uri!.toString());
      if (!mounted) return;
      setState(() => _competitor = competitor);
    } on SeoScrapeException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.userMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong while auditing that page.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.result;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: const BrandTitle(
          title: 'Competitor Compare',
          icon: Icons.compare_arrows_rounded,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: base == null
                  ? MessageCard(
                      icon: Icons.compare_arrows_rounded,
                      title: 'Audit a page first',
                      message: 'Comparison runs the same six checks against a '
                          'second URL, so start with the page you care about.',
                      action: FilledButton.icon(
                        onPressed: widget.onGoToAudit,
                        icon: const Icon(Icons.insights_rounded, size: 18),
                        label: const Text('Go to Audit Dashboard'),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _compareForm(context, base),
                        if (_isLoading) ...[
                          const SizedBox(height: 16),
                          const LoadingCard(
                            message: 'Auditing the competitor page…',
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          ErrorCard(message: _errorMessage!),
                        ],
                        if (_competitor != null) ...[
                          const SizedBox(height: 16),
                          _ScoreComparisonCard(
                            base: base,
                            competitor: _competitor!,
                          ),
                          const SizedBox(height: 16),
                          _CheckMatrixCard(base: base, competitor: _competitor!),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compareForm(BuildContext context, SeoAuditResult base) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Compare against',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Baseline: ${base.url}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) {
              if (_urlError != null) setState(() => _urlError = null);
            },
            onSubmitted: (_) => _compare(),
            decoration: InputDecoration(
              hintText: 'https://competitor.com',
              prefixIcon: const Icon(Icons.public_rounded),
              errorText: _urlError,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.tonalIcon(
              onPressed: _isLoading ? null : _compare,
              icon: const Icon(Icons.compare_arrows_rounded, size: 20),
              label: const Text('Run comparison'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreComparisonCard extends StatelessWidget {
  const _ScoreComparisonCard({required this.base, required this.competitor});

  final SeoAuditResult base;
  final SeoAuditResult competitor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final diff = base.score - competitor.score;

    final summary = diff == 0
        ? 'Both pages score ${base.score} out of 100.'
        : diff > 0
            ? 'This page scores $diff points higher.'
            : 'The competitor scores ${-diff} points higher.';

    final better = diff >= 0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.bar_chart_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Score comparison',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusChip(
                status:
                    better ? AuditStatus.good : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScoreTile(
                  label: 'This page',
                  url: base.url,
                  score: base.score,
                  highlighted: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScoreTile(
                  label: 'Competitor',
                  url: competitor.url,
                  score: competitor.score,
                  highlighted: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              summary,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.label,
    required this.url,
    required this.score,
    required this.highlighted,
  });

  final String label;
  final String url;
  final int score;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final band = ScoreBand.of(score);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$score',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: band.color(context),
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Uri.tryParse(url)?.host ?? url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckMatrixCard extends StatelessWidget {
  const _CheckMatrixCard({required this.base, required this.competitor});

  final SeoAuditResult base;
  final SeoAuditResult competitor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = base.checks.length;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(icon: Icons.fact_check_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Check by check',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 74,
                child: Text(
                  'This page',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 74,
                child: Text(
                  'Theirs',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          for (var i = 0; i < rows; i++) ...[
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    base.checks[i].label,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  width: 74,
                  child: Center(
                    child: PassFailChip(
                      passed: base.checks[i].status == AuditStatus.good,
                    ),
                  ),
                ),
                SizedBox(
                  width: 74,
                  child: Center(
                    child: PassFailChip(
                      passed: competitor.checks[i].status == AuditStatus.good,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
