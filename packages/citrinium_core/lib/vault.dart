/// Vault I/O: path normalization, BOM/line-ending-preserving atomic
/// read/write, directory scanning, and change watching.
///
/// This corresponds to `core/vault/` in `design.md` §6.1. It's pure Dart
/// and deliberately has no knowledge of Markdown structure -- that's the
/// parser/serializer (see `design.md` §3, upcoming in this package).
library;

export 'src/vault/ignore_rules.dart';
export 'src/vault/path_normalization.dart';
export 'src/vault/vault_file_io.dart';
export 'src/vault/vault_scanner.dart';
export 'src/vault/vault_watcher.dart';
