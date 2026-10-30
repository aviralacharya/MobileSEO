import 'package:flutter/material.dart';

import 'services/image_seo_checker.dart';
import 'services/seo_audit_service.dart';
import 'services/seo_extractor.dart';
import 'services/seo_scraper_service.dart';
import 'services/site_files_checker.dart';
import 'utils/url_validator.dart';

void main() {
  runApp(const SeoAuditApp());
}

class SeoAuditApp extends StatelessWidget {
  const SeoAuditApp({super.key});

  static const Color _seed = Color(0xFF3D5AFE);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MobileSEO',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF6F7FB) : scheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor:
            isLight ? const Color(0xFFF6F7FB) : scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final SiteFilesChecker _siteFilesChecker = SiteFilesChecker();
  static const SeoAuditService _auditService = SeoAuditService();

  bool _isLoading = false;
  String? _urlError;
  String? _errorMessage;
  SeoErrorKind? _errorKind;
  SeoAuditResult? _result;
  SiteFilesReport? _siteFiles;

  @override
  void dispose() {
    _urlController.dispose();
    _siteFilesChecker.close();
    super.dispose();
  }

  Future<void> _runAudit() async {
    if (_isLoading) return;

    // 1. Validate locally — bad input never reaches the network.
    final validation = UrlValidator.validate(_urlController.text);
    if (!validation.isValid) {
      setState(() {
        _urlError = validation.message;
        _errorMessage = null;
        _errorKind = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _urlError = null;
      _errorMessage = null;
      _errorKind = null;
      _siteFiles = null;
    });

    // The two crawl-file checks only need the host, so they can run while the
    // page itself is still downloading.
    final filesFuture = _siteFilesChecker.check(validation.uri!);

    try {
      // 2. extractSeo never throws: timeouts, 404s, 500s, blocked sites and
      //    non-HTML responses all come back as a failed snapshot.
      final snapshot = await extractSeo(validation.uri.toString());
      if (!mounted) return;

      if (!snapshot.isSuccess) {
        setState(() {
          _result = null;
          _errorMessage = snapshot.error;
          _errorKind = snapshot.errorKind;
        });
        _showErrorSnackBar(
          snapshot.error ?? 'The audit could not be completed.',
          retryable: _isRetryable(snapshot.errorKind),
        );
        return;
      }

      final siteFiles = await filesFuture;
      if (!mounted) return;

      setState(() {
        _result = _auditService.analyzeSnapshot(snapshot);
        _siteFiles = siteFiles;
        _errorMessage = null;
        _errorKind = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _errorMessage = 'Something went wrong while auditing this page.';
        _errorKind = SeoErrorKind.unknown;
      });
      _showErrorSnackBar('Something went wrong while auditing this page.');
      debugPrint('Audit failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Transient problems are worth another attempt; a 404 or a block is not.
  static bool _isRetryable(SeoErrorKind? kind) {
    return kind == null ||
        kind == SeoErrorKind.timeout ||
        kind == SeoErrorKind.network ||
        kind == SeoErrorKind.serverError;
  }

  void _showErrorSnackBar(String message, {bool retryable = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: retryable
              ? SnackBarAction(label: 'Retry', onPressed: _runAudit)
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.travel_explore_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEO Audit',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'MobileSEO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchCard(context),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildBody(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Audit a page',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a public URL and check the on-page SEO basics.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) {
              if (_urlError != null) {
                setState(() => _urlError = null);
              }
            },
            onSubmitted: (_) => _runAudit(),
            decoration: InputDecoration(
              hintText: 'https://example.com',
              prefixIcon: const Icon(Icons.link_rounded),
              helperText: 'https:// is added automatically',
              errorText: _urlError,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isLoading ? null : _runAudit,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoading
                    ? Row(
                        key: const ValueKey('loading'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Auditing…'),
                        ],
                      )
                    : const Row(
                        key: ValueKey('idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('Run SEO Audit'),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const _KeyedState(
        stateKey: 'loading',
        child: _LoadingCard(),
      );
    }
    if (_errorMessage != null) {
      return _KeyedState(
        stateKey: 'error',
        child: _ErrorCard(
          message: _errorMessage!,
          onRetry: _isRetryable(_errorKind) ? _runAudit : null,
        ),
      );
    }
    if (_result != null) {
      return _KeyedState(
        stateKey: 'result',
        child: _ResultsView(result: _result!, siteFiles: _siteFiles),
      );
    }
    return const _KeyedState(stateKey: 'empty', child: _EmptyState());
  }
}

/// Keeps `AnimatedSwitcher` transitions stable for each state.
class _KeyedState extends StatelessWidget {
  const _KeyedState({required this.stateKey, required this.child});

  final String stateKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: ValueKey(stateKey), child: child);
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.result, this.siteFiles});

  final SeoAuditResult result;
  final SiteFilesReport? siteFiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreCard(result: result),
        const SizedBox(height: 16),
        _MetaCard(check: result.checks[0], icon: Icons.title_rounded),
        const SizedBox(height: 16),
        _MetaCard(check: result.checks[1], icon: Icons.notes_rounded),
        const SizedBox(height: 16),
        _HeadingsCard(result: result),
        const SizedBox(height: 16),
        _ImagesCard(report: result.imageReport),
        const SizedBox(height: 16),
        _SchemaCard(result: result),
        if (siteFiles != null) ...[
          const SizedBox(height: 16),
          _SiteFilesCard(report: siteFiles!),
        ],
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result});

  final SeoAuditResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = _StatusPalette.of(
      context,
      result.score >= 80 ? AuditStatus.good : AuditStatus.warning,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: result.score / 100),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: scheme.surface.withValues(alpha: 0.7),
                        color: palette.color,
                      );
                    },
                  ),
                ),
                Text(
                  '${result.score}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEO score',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.passedCount} of ${result.checks.length} checks passed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.public_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        result.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.check, required this.icon});

  final AuditCheck check;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  check.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusChip(status: check.status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            check.value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            check.note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadingsCard extends StatelessWidget {
  const _HeadingsCard({required this.result});

  final SeoAuditResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h1Good = result.h1Count == 1;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBubble(icon: Icons.format_size_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Headings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusChip(
                status: h1Good ? AuditStatus.good : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HeadingRow(
            tag: 'H1',
            count: result.h1Count,
            caption: 'Primary heading',
            status: h1Good ? AuditStatus.good : AuditStatus.warning,
          ),
          const SizedBox(height: 10),
          _HeadingRow(
            tag: 'H2',
            count: result.h2Count,
            caption: 'Section headings',
            status: result.h2Count > 0
                ? AuditStatus.good
                : AuditStatus.warning,
          ),
          const SizedBox(height: 10),
          _HeadingRow(
            tag: 'H3',
            count: result.h3Count,
            caption: 'Sub-section headings',
            status: result.h3Count > 0
                ? AuditStatus.good
                : AuditStatus.warning,
          ),
        ],
      ),
    );
  }
}

class _HeadingRow extends StatelessWidget {
  const _HeadingRow({
    required this.tag,
    required this.count,
    required this.caption,
    required this.status,
  });

  final String tag;
  final int count;
  final String caption;
  final AuditStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = _StatusPalette.of(context, status);

    return Row(
      children: [
        Container(
          width: 46,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            tag,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                count == 0 ? 'None found' : '$count on the page',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: palette.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagesCard extends StatelessWidget {
  const _ImagesCard({required this.report});

  final ImageSeoReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = report.isHealthy ? AuditStatus.good : AuditStatus.warning;
    final palette = _StatusPalette.of(context, status);
    final visible = report.imagesMissingAlt.take(4).toList();
    final hidden = report.missingAltCount - visible.length;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBubble(icon: Icons.image_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Image SEO',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            report.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: report.coveragePercent / 100,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(palette.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.coveragePercent}% of images have alt text',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _MissingImageRow(issue: visible[i]),
            ],
            if (hidden > 0) ...[
              const SizedBox(height: 10),
              Text(
                '+ $hidden more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MissingImageRow extends StatelessWidget {
  const _MissingImageRow({required this.issue});

  final ImageIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.broken_image_outlined,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            issue.src,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            issue.hasEmptyAlt ? 'alt=""' : 'no alt',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SchemaCard extends StatelessWidget {
  const _SchemaCard({required this.result});

  final SeoAuditResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBubble(icon: Icons.code_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Schema markup',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusChip(
                status: result.hasSchema
                    ? AuditStatus.good
                    : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!result.hasSchema)
            Text(
              'No JSON-LD or microdata found. Structured data helps search '
              'engines show rich results.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in result.schemaTypes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      type,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SiteFilesCard extends StatelessWidget {
  const _SiteFilesCard({required this.report});

  final SiteFilesReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBubble(icon: Icons.travel_explore_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Crawl files',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusChip(
                status: report.allPassed
                    ? AuditStatus.good
                    : AuditStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Checked at the site root, independent of the audited page path.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _SiteFileRow(check: report.robots),
          const SizedBox(height: 12),
          _SiteFileRow(check: report.sitemap),
        ],
      ),
    );
  }
}

class _SiteFileRow extends StatelessWidget {
  const _SiteFileRow({required this.check});

  final SiteFileCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                check.fileName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                check.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _PassFailChip(passed: check.passed),
      ],
    );
  }
}

class _PassFailChip extends StatelessWidget {
  const _PassFailChip({required this.passed});

  final bool passed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = passed
        ? _StatusPalette.of(context, AuditStatus.good).color
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            passed ? 'Pass' : 'Fail',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AuditStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _StatusPalette.of(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(palette.icon, size: 14, color: palette.color),
          const SizedBox(width: 6),
          Text(
            palette.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPalette {
  const _StatusPalette(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;

  static _StatusPalette of(BuildContext context, AuditStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case AuditStatus.good:
        return _StatusPalette(
          isDark ? const Color(0xFF7BD88F) : const Color(0xFF1B873F),
          Icons.check_circle_rounded,
          'Good',
        );
      case AuditStatus.warning:
        return _StatusPalette(
          isDark ? const Color(0xFFFFC266) : const Color(0xFFB26A00),
          Icons.warning_amber_rounded,
          'Needs work',
        );
    }
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(
                icon: Icons.manage_search_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Fetching page and analysing tags…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not complete the audit',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.travel_explore_rounded,
              size: 34,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ready when you are',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter a URL above to see the title, description, headings and '
            'schema markup for that page.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
