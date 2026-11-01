import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../index/app_services.dart';
import '../index/index_providers.dart';
import '../vault/vault_path_provider.dart';
import '../workspace/workspace_state.dart';
import 'plugin_models.dart';
import 'plugin_service.dart';

final pluginServiceProvider = FutureProvider<PluginService?>((ref) async {
  final vaultPath = ref.watch(vaultPathProvider);
  if (vaultPath == null) return null;

  final services = await ref.watch(appServicesProvider.future);
  if (services == null) return null;

  final workspaceNotifier = ref.watch(workspaceStateProvider.notifier);
  final vaultMutation = ref.watch(vaultMutationProvider);

  return PluginService(
    vaultDir: Directory(vaultPath),
    workspaceStateNotifier: workspaceNotifier,
    vaultMutationService: vaultMutation,
    indexService: services.indexService,
    showToastCallback: (message) {
      debugPrint('[Plugin Notice]: $message');
    },
  );
});

final installedPluginsProvider = FutureProvider<List<PluginInfo>>((ref) async {
  final service = await ref.watch(pluginServiceProvider.future);
  final workspace = ref.watch(workspaceStateProvider);
  if (service == null) return const [];
  return service.discoverPlugins(workspace);
});

final corePluginsProvider = Provider<List<CorePluginInfo>>((ref) {
  final workspace = ref.watch(workspaceStateProvider);
  return CorePluginInfo.standard.map((c) {
    return CorePluginInfo(
      id: c.id,
      name: c.name,
      description: c.description,
      iconName: c.iconName,
      isEnabled: workspace.enabledCorePlugins.contains(c.id),
    );
  }).toList();
});
