import 'dart:convert';

import '../utils/page_identity.dart';
import 'local_store.dart';

class SavedProject {
  const SavedProject({
    required this.url,
    required this.name,
    required this.createdAt,
    this.favorite = false,
    this.inProgress = const {},
  });

  final String url, name;
  final DateTime createdAt;
  final bool favorite;
  final Set<String> inProgress;
  String get id => pageIdentity(url);

  SavedProject copyWith({
    String? name,
    bool? favorite,
    Set<String>? inProgress,
  }) => SavedProject(
    url: url,
    name: name ?? this.name,
    createdAt: createdAt,
    favorite: favorite ?? this.favorite,
    inProgress: Set.unmodifiable(inProgress ?? this.inProgress),
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'favorite': favorite,
    'inProgress': inProgress.toList(),
  };

  factory SavedProject.fromJson(Map<String, dynamic> data) => SavedProject(
    url: pageIdentity(data['url'] as String),
    name: data['name'] as String,
    createdAt: DateTime.parse(data['createdAt'] as String),
    favorite: data['favorite'] == true,
    inProgress: Set.unmodifiable(
      (data['inProgress'] as List? ?? []).cast<String>(),
    ),
  );
}

class ProjectService {
  ProjectService({LocalStore? store}) : _store = store ?? PreferencesStore();
  static const storageKey = 'mobile_seo.projects.v1';
  final LocalStore _store;

  Future<List<SavedProject>> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return [];
    final rows = jsonDecode(raw) as List;
    final projects = <String, SavedProject>{};
    for (final row in rows.whereType<Map>()) {
      try {
        final project = SavedProject.fromJson(Map<String, dynamic>.from(row));
        projects[project.id] = project;
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return projects.values.toList();
  }

  Future<void> save(List<SavedProject> projects) => _store.write(
    storageKey,
    jsonEncode(projects.map((project) => project.toJson()).toList()),
  );
}
