import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FixCodeGenerator extends StatefulWidget {
  const FixCodeGenerator({
    super.key,
    required this.type,
    required this.url,
    this.title = '',
    this.description = '',
    this.image = '',
    this.schemaTypes = const [],
  });
  final String type, url, title, description, image;
  final List<String> schemaTypes;
  @override
  State<FixCodeGenerator> createState() => _FixCodeGeneratorState();
}

class _FixCodeGeneratorState extends State<FixCodeGenerator> {
  late final TextEditingController _title, _description, _image;
  String _schema = 'Organization';
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title);
    _description = TextEditingController(text: widget.description);
    _image = TextEditingController(text: widget.image);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _image.dispose();
    super.dispose();
  }

  String get _code {
    final title = _title.text.trim(),
        description = _description.text.trim(),
        image = _image.text.trim();
    switch (widget.type) {
      case 'title':
        return '<title>${_escape(title)}</title>';
      case 'description':
        return '<meta name="description" content="${_escape(description)}">';
      case 'open_graph':
        return [
          '<meta property="og:title" content="${_escape(title)}">',
          '<meta property="og:description" content="${_escape(description)}">',
          '<meta property="og:image" content="${_escape(image)}">',
        ].join('\n');
      case 'viewport':
        return '<meta name="viewport" content="width=device-width, initial-scale=1">';
      default:
        final uri = Uri.tryParse(widget.url);
        final host = uri?.host ?? '';
        final Map<String, dynamic> data = switch (_schema) {
          'WebSite' => {
            '@context': 'https://schema.org',
            '@type': 'WebSite',
            'name': title.isEmpty ? host : title,
            'url': widget.url,
          },
          'LocalBusiness' => {
            '@context': 'https://schema.org',
            '@type': 'LocalBusiness',
            'name': title.isEmpty ? host : title,
            'url': widget.url,
            'image': image.isEmpty ? null : image,
            'description': description.isEmpty ? null : description,
          },
          'Article' => {
            '@context': 'https://schema.org',
            '@type': 'Article',
            'headline': title.isEmpty ? host : title,
            'description': description,
            'image': image.isEmpty ? null : [image],
            'mainEntityOfPage': widget.url,
          },
          _ => {
            '@context': 'https://schema.org',
            '@type': 'Organization',
            'name': title.isEmpty ? host : title,
            'url': widget.url,
            'logo': image.isEmpty ? null : image,
          },
        }..removeWhere((k, v) => v == null || v == '');
        return '<script type="application/ld+json">\n${const JsonEncoder.withIndent('  ').convert(data)}\n</script>';
    }
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fix code copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSchema = widget.type == 'schema';
    final isViewport = widget.type == 'viewport';
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSchema)
          DropdownButtonFormField<String>(
            value: _schema,
            decoration: const InputDecoration(labelText: 'Schema type'),
            items: const [
              'Organization',
              'WebSite',
              'LocalBusiness',
              'Article',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _schema = v ?? _schema),
          ),
        if (!isViewport) ...[
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: isSchema ? 'Name / headline' : 'Page title',
            ),
          ),
          if (widget.type != 'title') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              onChanged: (_) => setState(() {}),
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            if (widget.type == 'open_graph' || isSchema) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _image,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Social share image URL',
                ),
              ),
            ],
          ],
        ],
        if (isViewport)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Responsive viewport'),
            subtitle: Text('width=device-width, initial-scale=1'),
          ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.45,
                  color: theme.colorScheme.onSurface,
                ),
                children: _highlight(_code, theme.colorScheme),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy Code'),
        ),
      ],
    );
  }

  List<TextSpan> _highlight(String code, ColorScheme scheme) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(<[^>]+>|"[^"]*")');
    var pos = 0;
    for (final m in regex.allMatches(code)) {
      if (m.start > pos)
        spans.add(TextSpan(text: code.substring(pos, m.start)));
      final token = m.group(0)!;
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: token.startsWith('<') ? scheme.primary : scheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      pos = m.end;
    }
    if (pos < code.length) spans.add(TextSpan(text: code.substring(pos)));
    return spans;
  }
}
