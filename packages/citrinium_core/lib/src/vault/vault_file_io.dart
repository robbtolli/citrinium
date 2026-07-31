import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

const List<int> _utf8Bom = [0xEF, 0xBB, 0xBF];

/// Thrown when a file's bytes can't be decoded as UTF-8 (or UTF-8 + BOM).
///
/// Vault files are Markdown, expected to be UTF-8; a decode failure here
/// most likely means the file isn't actually text (or uses a different
/// encoding entirely), which callers should surface rather than silently
/// mangle.
class VaultFileDecodeException implements Exception {
  VaultFileDecodeException(this.path, this.source);

  final String path;
  final Object source;

  @override
  String toString() => 'VaultFileDecodeException: failed to decode $path as UTF-8 ($source)';
}

/// The decoded contents of a vault text file, plus the byte-level details
/// needed to write it back out identically.
///
/// [text] is exactly what was between the (optional) BOM and EOF, decoded as
/// UTF-8 -- line endings (LF/CRLF/CR/mixed) and trailing-newline presence
/// are preserved verbatim as part of the string, since we never trim or
/// re-encode them. [hadBom] records whether a UTF-8 BOM preceded the
/// content, so [writeVaultFileAtomic] can restore it.
class VaultFileContents {
  const VaultFileContents({required this.text, required this.hadBom});

  final String text;
  final bool hadBom;

  @override
  bool operator ==(Object other) =>
      other is VaultFileContents && other.text == text && other.hadBom == hadBom;

  @override
  int get hashCode => Object.hash(text, hadBom);

  @override
  String toString() => 'VaultFileContents(hadBom: $hadBom, ${text.length} chars)';
}

/// One of the line-ending conventions we might find in a vault file.
enum LineEndingStyle {
  /// `\n` only.
  lf,

  /// `\r\n` only.
  crlf,

  /// `\r` only (old classic Mac; rare, but a hostile fixture in W6 covers it).
  cr,

  /// More than one style present in the same file.
  mixed,

  /// No line breaks at all (e.g. an empty file, or a single line with no
  /// trailing newline).
  none,
}

final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');

/// Detects the dominant [LineEndingStyle] used in [text].
///
/// This never mutates or normalizes anything -- vault files preserve
/// whatever line endings they already had (including a mix of them) on
/// every read/write round-trip. This helper exists for consumers such as a
/// future "append a new line" edit that needs to know which convention to
/// match, and is exercised directly by the W6 fixture corpus.
LineEndingStyle detectLineEndingStyle(String text) {
  final found = <String>{};
  for (final match in _lineBreak.allMatches(text)) {
    found.add(match.group(0)!);
  }
  if (found.isEmpty) return LineEndingStyle.none;
  if (found.length > 1) return LineEndingStyle.mixed;
  switch (found.single) {
    case '\r\n':
      return LineEndingStyle.crlf;
    case '\r':
      return LineEndingStyle.cr;
    default:
      return LineEndingStyle.lf;
  }
}

/// Whether [text] ends with a line break (i.e. has a trailing newline).
bool hasTrailingNewline(String text) {
  return text.endsWith('\n') || text.endsWith('\r');
}

/// Reads and decodes [file], stripping (and recording) a leading UTF-8 BOM
/// if present.
///
/// Throws a [VaultFileDecodeException] if the bytes aren't valid UTF-8.
Future<VaultFileContents> readVaultFile(File file) async {
  final bytes = await file.readAsBytes();
  return _decode(file.path, bytes);
}

/// Synchronous counterpart to [readVaultFile].
VaultFileContents readVaultFileSync(File file) {
  final bytes = file.readAsBytesSync();
  return _decode(file.path, bytes);
}

VaultFileContents _decode(String path, Uint8List bytes) {
  final hasBom = bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
  final body = hasBom ? Uint8List.sublistView(bytes, 3) : bytes;
  try {
    final text = const Utf8Decoder(allowMalformed: false).convert(body);
    return VaultFileContents(text: text, hadBom: hasBom);
  } on FormatException catch (e) {
    throw VaultFileDecodeException(path, e);
  }
}

/// Writes [contents] to [file] atomically: the bytes are written to a
/// temporary file in the same directory, flushed, and then renamed over
/// [file]. A crash or power loss mid-write can therefore never leave [file]
/// truncated or partially written -- readers always see either the old
/// content or the fully-written new content, never something in between.
///
/// If [contents.hadBom] is true, a UTF-8 BOM is prepended before encoding,
/// matching whatever the file originally had.
Future<void> writeVaultFileAtomic(File file, VaultFileContents contents) async {
  final tempFile = _tempFileFor(file);
  final bytes = _encode(contents);
  final raf = await tempFile.open(mode: FileMode.writeOnly);
  try {
    await raf.writeFrom(bytes);
    await raf.flush();
  } finally {
    await raf.close();
  }
  await _renameOver(tempFile, file);
}

/// Synchronous counterpart to [writeVaultFileAtomic].
void writeVaultFileAtomicSync(File file, VaultFileContents contents) {
  final tempFile = _tempFileFor(file);
  final bytes = _encode(contents);
  final raf = tempFile.openSync(mode: FileMode.writeOnly);
  try {
    raf.writeFromSync(bytes);
    raf.flushSync();
  } finally {
    raf.closeSync();
  }
  try {
    tempFile.renameSync(file.path);
  } on FileSystemException {
    // Windows can refuse to replace an existing file in some
    // configurations; fall back to delete-then-rename. This narrows (but
    // doesn't eliminate) the atomicity window, only as a last resort.
    if (file.existsSync()) file.deleteSync();
    tempFile.renameSync(file.path);
  }
}

Uint8List _encode(VaultFileContents contents) {
  final body = utf8.encode(contents.text);
  if (!contents.hadBom) return Uint8List.fromList(body);
  return Uint8List.fromList([..._utf8Bom, ...body]);
}

File _tempFileFor(File file) {
  final dir = p.dirname(file.path);
  final base = p.basename(file.path);
  final unique = '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
  return File(p.join(dir, '.$base.tmp-$unique'));
}

Future<void> _renameOver(File tempFile, File target) async {
  try {
    await tempFile.rename(target.path);
  } on FileSystemException {
    if (await target.exists()) await target.delete();
    await tempFile.rename(target.path);
  }
}
