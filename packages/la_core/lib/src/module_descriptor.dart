enum ModuleKind { section, tool, launch }

/// Kern-Deskriptor ohne View-Builder (Issue #60): View-Factories
/// leben in den UI-Adaptern und binden ueber [viewId].
class ModuleDescriptor {
  const ModuleDescriptor({
    required this.id,
    required this.titleKey,
    required this.viewId,
    required this.kind,
    this.capabilities = const <String>{},
    this.requires = const <String>{},
    this.probeIds = const <String>{},
    this.actionIds = const <String>{},
    this.subscribedTopics = const <String>{},
  });

  final String id;
  final String titleKey;
  final String viewId;
  final ModuleKind kind;
  final Set<String> capabilities;
  final Set<String> requires;
  final Set<String> probeIds;
  final Set<String> actionIds;
  final Set<String> subscribedTopics;
}
