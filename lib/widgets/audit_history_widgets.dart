import 'package:flutter/material.dart';

import '../services/audit_history_service.dart';
import 'app_widgets.dart';

class AuditHistoryList extends StatefulWidget {
  const AuditHistoryList({
    super.key,
    required this.entries,
    required this.onDelete,
  });
  final List<AuditHistoryEntry> entries;

  /// Deletes one entry and returns the surviving history.
  final Future<List<AuditHistoryEntry>> Function(String id) onDelete;

  @override
  State<AuditHistoryList> createState() => _AuditHistoryListState();
}

class _AuditHistoryListState extends State<AuditHistoryList> {
  late List<AuditHistoryEntry> _entries = widget.entries;

  @override
  void didUpdateWidget(covariant AuditHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entries, widget.entries)) {
      _entries = widget.entries;
    }
  }

  Future<bool> _confirm(AuditHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this audit?'),
        content: Text('${entry.domain} will be removed from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _delete(AuditHistoryEntry entry) async {
    final previous = _entries;
    // Remove synchronously: Dismissible requires the item to leave the list
    // in the same frame it is dismissed.
    setState(() {
      _entries = _entries.where((e) => e.id != entry.id).toList();
    });
    try {
      final items = await widget.onDelete(entry.id);
      if (mounted) setState(() => _entries = items);
    } catch (_) {
      if (mounted) setState(() => _entries = previous);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Audit history',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${_entries.length} saved',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: _entries.isEmpty
              ? const Center(child: Text('Completed audits will appear here.'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final e = _entries[index];
                    return Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirm(e),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Theme.of(context).colorScheme.error,
                        child: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                      onDismissed: (_) => _delete(e),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${e.result.score}')),
                        title: Text(
                          e.domain,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${e.result.url}\n${_date(e.createdAt)} · ${e.result.passedCount}/${e.result.checks.length} checks passed',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop(e),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class ScoreTrendChart extends StatelessWidget {
  const ScoreTrendChart({super.key, required this.entries});
  final List<AuditHistoryEntry> entries;
  @override
  Widget build(BuildContext context) {
    final ordered = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (ordered.length < 2) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEO score over time',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${ordered.first.domain} · ${ordered.length} audits',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _ScoreChartPainter(
                scores: ordered.map((e) => e.result.score).toList(),
                lineColor: scheme.primary,
                gridColor: scheme.outlineVariant,
                textColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Audit #1', style: Theme.of(context).textTheme.labelSmall),
              Text(
                'Audit #${ordered.length}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  const _ScoreChartPainter({
    required this.scores,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });
  final List<int> scores;
  final Color lineColor, gridColor, textColor;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, right = 12.0, top = 12.0, bottom = 20.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final grid = Paint()
      ..color = gridColor.withValues(alpha: .65)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final score in [0, 50, 100]) {
      final y = plot.bottom - (score / 100) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      textPainter.text = TextSpan(
        text: '$score',
        style: TextStyle(fontSize: 10, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }
    final pts = <Offset>[];
    for (var i = 0; i < scores.length; i++) {
      final x = scores.length == 1
          ? plot.center.dx
          : plot.left + i * plot.width / (scores.length - 1);
      pts.add(
        Offset(x, plot.bottom - (scores[i].clamp(0, 100) / 100) * plot.height),
      );
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p = pts[i], n = pts[i + 1], mid = (p.dx + n.dx) / 2;
      path.cubicTo(mid, p.dy, mid, n.dy, n.dx, n.dy);
    }
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);
    final dot = Paint()..color = lineColor;
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 4, dot);
      textPainter.text = TextSpan(
        text: '${scores[i]}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      );
      textPainter.layout();
      final dx = (pts[i].dx - textPainter.width / 2).clamp(
        plot.left,
        plot.right - textPainter.width,
      );
      final dy = (pts[i].dy - 18).clamp(plot.top, plot.bottom - 10);
      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter old) =>
      old.scores != scores ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor;
}
