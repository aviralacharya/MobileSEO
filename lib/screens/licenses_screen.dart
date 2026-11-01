import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';

/// Uses Flutter's license registry while retaining the shared screen header.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  late Future<Map<String, List<LicenseEntry>>> _licenses = _load();

  Future<Map<String, List<LicenseEntry>>> _load() async {
    final packages = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        packages.putIfAbsent(package, () => []).add(entry);
      }
    }
    final names = packages.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final name in names) name: packages[name]!};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BrandTitle(title: 'Open-source licenses')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: FutureBuilder<Map<String, List<LicenseEntry>>>(
            future: _licenses,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: MessageCard(
                    icon: Icons.description_outlined,
                    title: 'Licenses unavailable',
                    message:
                        'The bundled license information could not be read.',
                    action: TextButton(
                      onPressed: () => setState(() => _licenses = _load()),
                      child: const Text('Try again'),
                    ),
                  ),
                );
              }
              final packages = snapshot.data?.entries.toList();
              if (packages == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (packages.isEmpty) {
                return const Center(child: Text('No bundled licenses found.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: packages.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final package = packages[index];
                  final count = package.value.length;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(package.key),
                    subtitle: Text(
                      '$count ${count == 1 ? 'license' : 'licenses'}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _PackageLicenses(
                          name: package.key,
                          entries: package.value,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _PackageLicenses extends StatelessWidget {
  const _PackageLicenses({required this.name, required this.entries});

  final String name;
  final List<LicenseEntry> entries;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: BrandTitle(title: name)),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: SelectionArea(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 32),
              itemBuilder: (context, index) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final paragraph in entries[index].paragraphs)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: paragraph.indent.clamp(0, 3) * 16.0,
                        bottom: 12,
                      ),
                      child: Text(
                        paragraph.text,
                        textAlign:
                            paragraph.indent == LicenseParagraph.centeredIndent
                            ? TextAlign.center
                            : TextAlign.start,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
