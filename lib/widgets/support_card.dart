import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_widgets.dart';

const supportEmail = 'abiralacharya8@gmail.com';

class SupportCard extends StatelessWidget {
  const SupportCard({super.key});

  Future<void> _email(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await launchUrl(
        Uri(
          scheme: 'mailto',
          path: supportEmail,
          query: 'subject=${Uri.encodeComponent('MobileSEO support')}',
        ),
      );
      if (opened) return;
    } catch (_) {
      // The copy action is also available on devices without a mail app.
    }
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No email app available. You can copy the support address below.',
          ),
        ),
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Email address copied')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not copy the address. Select the text to copy it manually.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Here to help', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text('Questions, feedback or a page that needs a closer look?'),
        const SizedBox(height: 12),
        const SelectableText(supportEmail),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _email(context),
              icon: const Icon(Icons.mail_outline_rounded),
              label: const Text('Email support'),
            ),
            TextButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy email'),
            ),
          ],
        ),
      ],
    ),
  );
}
