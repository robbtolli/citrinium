/// Bumped whenever a change to this parser (grammar, span computation, or
/// the index-layer mapping in `src/index/document_indexer.dart`) could
/// change the result of parsing an unchanged file.
///
/// `IndexService` stores the version it last indexed with in
/// `index_meta['parserVersion']`; a mismatch on open (including "no value
/// yet", i.e. a brand-new database) triggers a full rebuild rather than
/// trusting stale rows, per `docs/milestones/m0.md` W3.
const int currentParserVersion = 1;
