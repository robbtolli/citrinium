import 'path_normalization.dart';

/// Directory (or file) names that are always excluded from vault scanning
/// and watching, in addition to the generic "dotfile/dotdir" rule in
/// [isIgnoredName].
///
/// Most of these (`.git`, `.obsidian`, `.citrinium`, `.trash`) already start
/// with `.` and would be caught by that generic rule; they're listed
/// explicitly anyway so the ignore policy is self-documenting and doesn't
/// quietly depend on every future vault-config directory happening to start
/// with a dot. `node_modules` is the one entry that genuinely needs the
/// explicit list.
const Set<String> defaultIgnoredDirNames = {
  '.git',
  '.obsidian',
  '.citrinium',
  '.trash',
  'node_modules',
};

/// Whether [name] (a single path segment - a file or directory *name*, not
/// a path) should be ignored under the vault's default ignore rules.
///
/// This covers both dotfiles/dotdirs (`.git`, `.obsidian`, `.DS_Store`, ...)
/// and the extra names in [ignoredDirNames].
bool isIgnoredName(
  String name, {
  Set<String> ignoredDirNames = defaultIgnoredDirNames,
}) {
  if (name.isEmpty) return false;
  return name.startsWith('.') || ignoredDirNames.contains(name);
}

/// Whether [name] (a file name, e.g. from [VaultPath.fileName]) has a
/// Markdown extension.
bool isMarkdownFileName(String name) => name.toLowerCase().endsWith('.md');

/// Whether [path] should be scanned/watched/indexed under the vault's
/// default ignore rules: no ignored directory in its ancestry, the file
/// itself isn't a dotfile, and it has a `.md` extension.
bool isTrackedVaultPath(
  VaultPath path, {
  Set<String> ignoredDirNames = defaultIgnoredDirNames,
}) {
  final segments = path.segments;
  if (segments.isEmpty) return false;

  for (final dir in path.directorySegments) {
    if (isIgnoredName(dir, ignoredDirNames: ignoredDirNames)) return false;
  }

  final fileName = path.fileName;
  if (isIgnoredName(fileName, ignoredDirNames: ignoredDirNames)) return false;

  return isMarkdownFileName(fileName);
}
