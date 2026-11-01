import 'package:flutter/material.dart';

import '../controllers/workspace_controller.dart';
import '../services/project_service.dart';
import '../utils/url_validator.dart';
import 'app_sheet.dart';

Future<bool?> showProjectEditor(
  BuildContext context,
  WorkspaceController workspace, {
  SavedProject? project,
  String? initialUrl,
}) => AppSheet.show<bool>(
  context: context,
  builder: (_) => _ProjectEditor(
    workspace: workspace,
    project: project,
    initialUrl: initialUrl,
  ),
);

class _ProjectEditor extends StatefulWidget {
  const _ProjectEditor({
    required this.workspace,
    this.project,
    this.initialUrl,
  });
  final WorkspaceController workspace;
  final SavedProject? project;
  final String? initialUrl;
  @override
  State<_ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<_ProjectEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.project?.name);
  late final _url = TextEditingController(
    text: widget.project?.url ?? widget.initialUrl,
  );
  late bool _favorite = widget.project?.favorite ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.workspace.saveProject(
        _url.text,
        name: _name.text,
        favorite: _favorite,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save the project. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.project == null ? 'Save a project' : 'Edit project',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep a page, its audit history and your next fixes together.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Project name',
                hintText: 'e.g. My store · Homepage',
                helperText: 'Optional. Defaults to the website name.',
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _url,
              readOnly: widget.project != null,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              validator: (value) => UrlValidator.validate(value ?? '').message,
              decoration: const InputDecoration(
                labelText: 'Page URL',
                hintText: 'https://example.com',
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Favorite project'),
              value: _favorite,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _favorite = value),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(_saving ? 'Saving…' : 'Save project'),
            ),
          ],
        ),
      ),
    ),
  );
}
