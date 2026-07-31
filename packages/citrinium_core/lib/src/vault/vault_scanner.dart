import 'dart:io';

import 'ignore_rules.dart';
import 'path_normalization.dart';

/// Why a would-be Markdown file was excluded from a [VaultScanResult].
enum VaultScanSkipReason {
  /// The file's size exceeds [VaultScanOptions.maxFileSizeBytes].
  tooLarge,

  /// The path is a symlink and [VaultScanOptions.followSymlinks] is false.
  symlinkNotFollowed,

  /// The file couldn't be `stat`'d (e.g. removed mid-scan, permission
  /// denied). Not fatal to the overall scan.
  unreadable,
}

/// A `.md` file discovered by [VaultScanner.scan].
class VaultScanEntry {
  const VaultScanEntry({
    required this.path,
    required this.absolutePath,
    required this.sizeBytes,
    required this.modifiedTime,
  });

  /// The file's canonical, vault-relative path.
  final VaultPath path;

  /// The OS-native absolute path, for direct file I/O.
  final String absolutePath;

  final int sizeBytes;
  final DateTime modifiedTime;

  @override
  String toString() => 'VaultScanEntry($path, ${sizeBytes}B)';
}

/// A `.md` file (or symlink to one) that [VaultScanner.scan] found but
/// didn't include in [VaultScanResult.files], along with why.
class VaultScanSkip {
  const VaultScanSkip({required this.path, required this.reason});

  final VaultPath path;
  final VaultScanSkipReason reason;

  @override
  String toString() => 'VaultScanSkip($path, $reason)';
}

/// The result of a full [VaultScanner.scan]: every trackable `.md` file
/// found, plus any candidates that were deliberately excluded (with a
/// reason a settings/diagnostics screen could surface later).
class VaultScanResult {
  const VaultScanResult({required this.files, required this.skipped});

  final List<VaultScanEntry> files;
  final List<VaultScanSkip> skipped;
}

/// Options controlling how [VaultScanner.scan] walks the vault.
class VaultScanOptions {
  const VaultScanOptions({
    this.maxFileSizeBytes = 10 * 1024 * 1024,
    this.followSymlinks = false,
    this.ignoredDirNames = defaultIgnoredDirNames,
  });

  /// `.md` files larger than this are excluded (reported as
  /// [VaultScanSkipReason.tooLarge]) rather than loaded fully into memory.
  final int maxFileSizeBytes;

  /// Whether to descend into / read through symlinks. Defaults to false:
  /// an unbounded vault directory tree containing a symlink cycle would
  /// otherwise hang the scanner.
  final bool followSymlinks;

  /// Directory (or file) names that are pruned outright, in addition to
  /// the generic dotfile/dotdir rule -- see [isIgnoredName].
  final Set<String> ignoredDirNames;
}

/// Enumerates the Markdown files in a vault, applying ignore rules
/// (`.git`, `.obsidian`, `.citrinium`, `.trash`, `node_modules`, dotfiles),
/// a file-size cap, and a symlink policy.
///
/// This is pure I/O enumeration -- no parsing. The index layer (W3) is
/// what turns this into `documents` rows.
class VaultScanner {
  const VaultScanner({this.options = const VaultScanOptions()});

  final VaultScanOptions options;

  /// Scans [vaultRootPath] (an absolute, OS-native directory path).
  Future<VaultScanResult> scan(String vaultRootPath) async {
    final files = <VaultScanEntry>[];
    final skipped = <VaultScanSkip>[];
    final visitedRealDirs = <String>{};

    await _walk(
      Directory(vaultRootPath),
      vaultRootPath,
      files,
      skipped,
      visitedRealDirs,
    );

    return VaultScanResult(files: files, skipped: skipped);
  }

  Future<void> _walk(
    Directory dir,
    String vaultRootPath,
    List<VaultScanEntry> files,
    List<VaultScanSkip> skipped,
    Set<String> visitedRealDirs,
  ) async {
    if (options.followSymlinks) {
      final real = dir.resolveSymbolicLinksSync();
      if (!visitedRealDirs.add(real)) {
        return; // symlink cycle guard
      }
    }

    List<FileSystemEntity> entities;
    try {
      entities = await dir.list(followLinks: options.followSymlinks).toList();
    } on FileSystemException {
      return; // directory disappeared or unreadable mid-scan
    }

    for (final entity in entities) {
      final name = _basename(entity.path);

      if (entity is Directory) {
        if (isIgnoredName(name, ignoredDirNames: options.ignoredDirNames)) {
          continue;
        }
        await _walk(entity, vaultRootPath, files, skipped, visitedRealDirs);
        continue;
      }

      if (entity is Link) {
        // followLinks was false, so we only ever see Link objects for
        // symlinks here; decide purely from the literal target string
        // without following it, per the "don't follow symlinks" policy.
        if (isIgnoredName(name, ignoredDirNames: options.ignoredDirNames)) {
          continue;
        }
        if (!isMarkdownFileName(name)) continue;
        final vaultPath = VaultPath.fromAbsolute(vaultRootPath, entity.path);
        skipped.add(
          VaultScanSkip(path: vaultPath, reason: VaultScanSkipReason.symlinkNotFollowed),
        );
        continue;
      }

      if (entity is File) {
        if (isIgnoredName(name, ignoredDirNames: options.ignoredDirNames)) {
          continue;
        }
        if (!isMarkdownFileName(name)) continue;

        final vaultPath = VaultPath.fromAbsolute(vaultRootPath, entity.path);
        FileStat stat;
        try {
          stat = await entity.stat();
        } on FileSystemException {
          skipped.add(
            VaultScanSkip(path: vaultPath, reason: VaultScanSkipReason.unreadable),
          );
          continue;
        }

        if (stat.size > options.maxFileSizeBytes) {
          skipped.add(
            VaultScanSkip(path: vaultPath, reason: VaultScanSkipReason.tooLarge),
          );
          continue;
        }

        files.add(
          VaultScanEntry(
            path: vaultPath,
            absolutePath: entity.path,
            sizeBytes: stat.size,
            modifiedTime: stat.modified,
          ),
        );
      }
    }
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx == -1 ? normalized : normalized.substring(idx + 1);
  }
}
