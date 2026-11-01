import 'package:citrinium_core/citrinium_core.dart';
import 'package:flutter/foundation.dart';

/// Exception thrown when a sandboxed plugin attempts an operation requiring
/// an ungranted permission (PL-02, PL-05).
class PluginSecurityException implements Exception {
  const PluginSecurityException(this.message);
  final String message;

  @override
  String toString() => 'PluginSecurityException: $message';
}

/// Result of evaluating a plugin script or running an automated plugin hook.
@immutable
class PluginExecutionResult {
  const PluginExecutionResult({
    required this.pluginId,
    required this.success,
    this.output = '',
    this.errorMessage,
    this.executionTimeMs = 0,
  });

  final String pluginId;
  final bool success;
  final String output;
  final String? errorMessage;
  final int executionTimeMs;

  @override
  String toString() =>
      'PluginExecutionResult($pluginId, success: $success, time: ${executionTimeMs}ms)';
}

/// Full metadata and runtime state of an installed plugin (community or core).
@immutable
class PluginInfo {
  const PluginInfo({
    required this.manifest,
    required this.dirPath,
    required this.isEnabled,
    required this.isCore,
    required this.grantedPermissions,
    required this.installedAtMs,
    this.lastResult,
  });

  final PluginManifest manifest;
  final String dirPath;
  final bool isEnabled;
  final bool isCore;
  final Set<PluginPermission> grantedPermissions;
  final int installedAtMs;
  final PluginExecutionResult? lastResult;

  String get id => manifest.id;
  String get name => manifest.name;
  String get version => manifest.version;
  String get description => manifest.description;
  String get author => manifest.author;

  bool hasPermission(PluginPermission permission) =>
      grantedPermissions.contains(permission);

  PluginInfo copyWith({
    bool? isEnabled,
    Set<PluginPermission>? grantedPermissions,
    PluginExecutionResult? lastResult,
  }) {
    return PluginInfo(
      manifest: manifest,
      dirPath: dirPath,
      isEnabled: isEnabled ?? this.isEnabled,
      isCore: isCore,
      grantedPermissions: grantedPermissions ?? this.grantedPermissions,
      installedAtMs: installedAtMs,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

/// Built-in core plugin descriptor (PL-08).
@immutable
class CorePluginInfo {
  const CorePluginInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.isEnabled,
  });

  final String id;
  final String name;
  final String description;
  final String iconName;
  final bool isEnabled;

  static const List<CorePluginInfo> standard = [
    CorePluginInfo(
      id: 'daily_notes',
      name: 'Daily Rapid Logging',
      description: 'Streamlined date-based journal logging on Today (daily/YYYY-MM-DD.md).',
      iconName: 'today',
      isEnabled: true,
    ),
    CorePluginInfo(
      id: 'templates',
      name: 'Cadence Templates',
      description: 'Customizable markdown templates with dynamic horizon expansion.',
      iconName: 'description',
      isEnabled: true,
    ),
    CorePluginInfo(
      id: 'gtd_clarify',
      name: 'GTD Clarify Flow',
      description: 'Decision-tree deck routing inbox items to Next Actions, Projects, or Someday.',
      iconName: 'fact_check',
      isEnabled: true,
    ),
    CorePluginInfo(
      id: 'hard_calendar',
      name: 'Hard-Landscape Calendar',
      description: 'Chronological timeline dedicated strictly to date/time commitments.',
      iconName: 'calendar_month',
      isEnabled: true,
    ),
  ];
}
