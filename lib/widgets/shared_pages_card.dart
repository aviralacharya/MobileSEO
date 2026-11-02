import 'package:flutter/material.dart';

import '../services/incoming_share_service.dart';
import 'app_widgets.dart';

/// Multiple shared links need a choice; an active audit needs an explicit
/// start action. A single link received while idle goes straight to the form.
class SharedPagesCard extends StatelessWidget {
  const SharedPagesCard({
    super.key,
    required this.pages,
    required this.auditRunning,
    required this.onSelect,
    required this.onDismiss,
  });

  final SharedPages pages;
  final bool auditRunning;
  final ValueChanged<Uri> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.move_to_inbox_outlined, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pages.error != null
                    ? 'Share a page link'
                    : pages.urls.length == 1
                    ? 'Shared page ready'
                    : 'Choose a shared page',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Dismiss shared link',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        if (pages.error != null)
          Text(pages.error!)
        else ...[
          Text(
            auditRunning
                ? 'Your current audit is still running. Choose a shared page to start a new audit.'
                : 'Choose which URL to put in the audit field.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              primary: false,
              itemCount: pages.urls.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  pages.urls[index].toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  auditRunning ? 'Audit shared page' : 'Use this URL',
                ),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => onSelect(pages.urls[index]),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
