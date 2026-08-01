/// Offset-preserving Markdown parser/serializer.
///
/// This corresponds to `design.md` §3 (vault & file schema) and
/// `docs/milestones/m0.md` W2. `MarkdownDocument.rawText` is always
/// authoritative; every other type here is offsets into it (see
/// `Span`), and there is no separate serialize step -- the serialized form
/// of a document is exactly its `rawText`.
library;

export 'src/parser/bujo.dart';
export 'src/parser/frontmatter.dart';
export 'src/parser/inline_metadata.dart';
export 'src/parser/markdown_document.dart';
export 'src/parser/parsed_line.dart';
export 'src/parser/parser_version.dart';
export 'src/parser/span.dart';
export 'src/parser/task_state.dart';
export 'src/parser/wikilink.dart';
