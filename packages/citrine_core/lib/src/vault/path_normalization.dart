import 'package:path/path.dart' as p;
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Normalizes [input] to Unicode Normalization Form C (NFC): composed
/// characters where possible (e.g. a single `é` code point).
String toNfc(String input) => unorm.nfc(input);

/// Normalizes [input] to Unicode Normalization Form D (NFD): fully
/// decomposed characters (e.g. `e` + combining acute accent).
///
/// Mainly useful for tests and for talking to filesystems (APFS) that hand
/// back NFD paths, so we can build fixtures without guessing at combining
/// character sequences by hand.
String toNfd(String input) => unorm.nfd(input);

/// A path relative to a vault root, held in a canonical form so that two
/// references to "the same" file compare equal regardless of incidental
/// differences in how the string was produced.
///
/// Canonicalization applied:
///
/// - Path separators are normalized to `/`, regardless of host OS.
/// - `.`/`..` segments are resolved (via [p.posix.normalize]).
/// - No leading or trailing `/`.
/// - Every path *segment* is Unicode-normalized to NFC.
///
/// The last point matters concretely: APFS (macOS) returns decomposed (NFD)
/// filenames from directory listings even for files created with composed
/// (NFC) names (and vice versa depending on how the name was typed). Without
/// normalizing at this boundary, a `[[wikilink]]` written in NFC would
/// silently fail to resolve against a scanned NFD filename, or two logically
/// identical [VaultPath]s could compare unequal and be double-counted.
class VaultPath {
  /// Builds a [VaultPath] from [rawRelativePath], which may use either `/`
  /// or `\` as a separator and may be in any Unicode normalization form.
  factory VaultPath(String rawRelativePath) {
    return VaultPath._(_normalize(rawRelativePath));
  }

  const VaultPath._(this.value);

  /// The canonical, `/`-separated, NFC-normalized relative path.
  final String value;

  /// Builds a [VaultPath] for [absolutePath], relative to [vaultRoot].
  ///
  /// Both arguments are plain OS path strings (as returned by `dart:io`),
  /// not yet normalized.
  factory VaultPath.fromAbsolute(String vaultRoot, String absolutePath) {
    final relative = p.relative(absolutePath, from: vaultRoot);
    return VaultPath(relative);
  }

  static String _normalize(String raw) {
    final posixForm = raw.replaceAll('\\', '/');
    var normalized = p.posix.normalize(posixForm);
    if (normalized == '.') normalized = '';
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.isEmpty) return '';
    return normalized.split('/').map(toNfc).join('/');
  }

  /// The path split into its `/`-separated segments.
  List<String> get segments => value.isEmpty ? const [] : value.split('/');

  /// The final segment (i.e. the file or directory name).
  String get fileName => segments.isEmpty ? '' : segments.last;

  /// The segments other than [fileName], i.e. the containing directories.
  List<String> get directorySegments =>
      segments.isEmpty ? const [] : segments.sublist(0, segments.length - 1);

  /// Resolves this path to an absolute, OS-native path under [vaultRoot].
  String toAbsolute(String vaultRoot) {
    if (segments.isEmpty) return p.normalize(vaultRoot);
    return p.joinAll([vaultRoot, ...segments]);
  }

  @override
  bool operator ==(Object other) => other is VaultPath && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
