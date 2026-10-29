import 'dart:io';

import '../parser/markdown_document.dart';
import 'path_normalization.dart';
import 'vault_file_io.dart';
import 'vault_watcher.dart';

/// Supported planning and review cadences (`B-01`–`B-03`, `B-11`, `B-12`,
/// `D-11`, `Q-01`, `Y-01`).
enum CadenceKind {
  daily(
    id: 'daily',
    label: 'Daily',
    docType: 'dailyLog',
    defaultEnabled: true,
    description: 'Daily rapid-log stream & end-of-day migration (2 min)',
  ),
  weekly(
    id: 'weekly',
    label: 'Weekly',
    docType: 'weeklyLog',
    defaultEnabled: true,
    description: 'Weekly focus plan & guided GTD Weekly Review (10–15 min)',
  ),
  monthly(
    id: 'monthly',
    label: 'Monthly',
    docType: 'monthlyLog',
    defaultEnabled: true,
    description: 'Monthly key dates timeline, open loops & habit check-in',
  ),
  quarterly(
    id: 'quarterly',
    label: 'Quarterly',
    docType: 'quarterlyLog',
    defaultEnabled: false,
    description: 'Quarter themes, Horizon 3 goals & Areas of Focus balance',
  ),
  yearly(
    id: 'yearly',
    label: 'Yearly',
    docType: 'yearlyLog',
    defaultEnabled: false,
    description: 'Annual themes, long-term vision & year-in-review reflection',
  ),
  future(
    id: 'future',
    label: 'Future Log',
    docType: 'futureLog',
    defaultEnabled: true,
    description: 'Items scheduled beyond the current month (<)',
  );

  const CadenceKind({
    required this.id,
    required this.label,
    required this.docType,
    required this.defaultEnabled,
    required this.description,
  });

  final String id;
  final String label;
  final String docType;
  final bool defaultEnabled;
  final String description;

  static CadenceKind? fromId(String id) {
    for (final value in CadenceKind.values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// File naming, default functional templates (`B-11`, `A-07`), and lazy
/// create-on-first-use helpers (`B-09`, `D-11`) for Citrinium vault files.
class CadenceFiles {
  const CadenceFiles._();

  static const String inboxRelPath = 'inbox.md';
  static const String futureLogRelPath = 'future.md';
  static const String somedayRelPath = 'someday.md';

  /// Relative path for the given [cadence] at [date] (per `docs/file-schema.md` §2).
  static String relPathForCadence(CadenceKind cadence, DateTime date) {
    switch (cadence) {
      case CadenceKind.daily:
        return dailyRelPath(date);
      case CadenceKind.weekly:
        return weeklyRelPath(date);
      case CadenceKind.monthly:
        return monthlyRelPath(date);
      case CadenceKind.quarterly:
        return quarterlyRelPath(date);
      case CadenceKind.yearly:
        return yearlyRelPath(date);
      case CadenceKind.future:
        return futureLogRelPath;
    }
  }

  static String dailyRelPath(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'daily/$y-$m-$d.md';
  }

  static String weeklyRelPath(DateTime date) {
    final iso = isoWeekYearAndNumber(date);
    final y = iso.year.toString().padLeft(4, '0');
    final w = iso.week.toString().padLeft(2, '0');
    return 'weekly/$y-W$w.md';
  }

  static String monthlyRelPath(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return 'monthly/$y-$m.md';
  }

  static String quarterlyRelPath(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final q = ((date.month - 1) ~/ 3) + 1;
    return 'quarterly/$y-Q$q.md';
  }

  static String yearlyRelPath(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    return 'yearly/$y.md';
  }

  /// Computes ISO-8601 week-numbering year and week number (1..53).
  static ({int year, int week}) isoWeekYearAndNumber(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    final dayOfWeek = utc.weekday; // 1 = Mon .. 7 = Sun
    final thursday = utc.add(Duration(days: 4 - dayOfWeek));
    final firstJan = DateTime.utc(thursday.year, 1, 1);
    final daysSinceFirstJan = thursday.difference(firstJan).inDays;
    final weekNumber = 1 + (daysSinceFirstJan ~/ 7);
    return (year: thursday.year, week: weekNumber);
  }

  /// Returns the initial Markdown content for a newly-created cadence file,
  /// checking `.citrinium/templates/<id>.md` first so user-customized templates
  /// (`B-11`) are honored automatically.
  static String defaultContentForCadence(
    CadenceKind cadence,
    DateTime date, {
    String? vaultRootPath,
    Set<CadenceKind>? enabledCadences,
    bool includeStarterTutorial = false,
  }) {
    if (vaultRootPath != null) {
      final customTemplateFile = File(
        VaultPath('.citrinium/templates/${cadence.id}.md')
            .toAbsolute(vaultRootPath),
      );
      if (customTemplateFile.existsSync()) {
        return readVaultFileSync(customTemplateFile).text;
      }
    }

    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final q = ((date.month - 1) ~/ 3) + 1;
    final iso = isoWeekYearAndNumber(date);
    final w = iso.week.toString().padLeft(2, '0');

    switch (cadence) {
      case CadenceKind.daily:
        if (includeStarterTutorial) {
          return '---\n'
              'citrinium:\n'
              '  type: dailyLog\n'
              '---\n'
              '# Daily Log — $y-$m-$d\n\n'
              '- [ ] Tap this checkbox or click this task to edit it in-place @computer\n'
              '- [ ] Try Quick Capture below with a phrase like "tomorrow 5pm" @home\n'
              '- – Tip: Start lines with "- [ ]" for tasks, "- ○" for events, or "- –" for notes\n';
        }
        return '---\n'
            'citrinium:\n'
            '  type: dailyLog\n'
            '---\n'
            '# Daily Log — $y-$m-$d\n\n';

      case CadenceKind.weekly:
        return '---\n'
            'citrinium:\n'
            '  type: weeklyLog\n'
            '---\n'
            '# Weekly Plan — ${iso.year}-W$w\n\n'
            'Horizon: [[monthly/$y-$m]]\n\n'
            '## This Week\'s Focus Outcomes\n'
            '- [ ] \n\n'
            '## Notes & Review Reflections\n'
            '- – \n';

      case CadenceKind.monthly:
        return '---\n'
            'citrinium:\n'
            '  type: monthlyLog\n'
            '---\n'
            '# Monthly Log — $y-$m\n\n'
            '## Key Dates & Events\n'
            '- ○ \n\n'
            '## Monthly Focus & Open Loops\n'
            '- [ ] \n';

      case CadenceKind.quarterly:
        return '---\n'
            'citrinium:\n'
            '  type: quarterlyLog\n'
            '---\n'
            '# Quarterly Plan — $y-Q$q\n\n'
            '## Quarter Themes & Outcomes (Horizon 3)\n'
            '- [ ] \n\n'
            '## Areas of Focus Check-in (Horizon 2)\n'
            '- – Health & Energy:\n'
            '- – Work & Projects:\n'
            '- – Relationships & Home:\n';

      case CadenceKind.yearly:
        return '---\n'
            'citrinium:\n'
            '  type: yearlyLog\n'
            '---\n'
            '# Yearly Log — $y\n\n'
            '## Annual Themes & Vision (Horizon 4)\n'
            '- – \n\n'
            '## Core Goals for $y\n'
            '- [ ] \n';

      case CadenceKind.future:
        return '---\n'
            'citrinium:\n'
            '  type: futureLog\n'
            '---\n'
            '# Future Log\n\n'
            '## Upcoming Months\n'
            '- [ ] \n\n'
            '## Undated Future\n'
            '- [ ] \n';
    }
  }

  static String defaultInboxContent() => '---\n'
      'citrinium:\n'
      '  type: inbox\n'
      '---\n'
      '# Inbox\n\n';

  static String defaultSomedayContent() => '---\n'
      'citrinium:\n'
      '  type: someday\n'
      '---\n'
      '# Someday / Maybe\n\n';

  /// Lazily creates [relPath] with [initialContent] if it does not yet exist
  /// on disk (`B-09`, `D-11`). Never overwrites an existing file.
  static Future<File> ensureVaultFile({
    required String vaultRootPath,
    required String relPath,
    required String initialContent,
    VaultWatcher? watcher,
  }) async {
    final absPath = VaultPath(relPath).toAbsolute(vaultRootPath);
    final file = File(absPath);
    if (await file.exists()) return file;

    watcher?.suppressSelfWrite(VaultPath(absPath));
    await writeVaultFileAtomic(
      file,
      VaultFileContents(text: initialContent, hadBom: false),
    );
    return file;
  }

  /// Appends [lineText] to [relPath] (creating the file lazily with
  /// [initialContentIfMissing] if it doesn't exist yet) and returns the
  /// updated [MarkdownDocument].
  static Future<MarkdownDocument> appendLineToVaultFile({
    required String vaultRootPath,
    required String relPath,
    required String lineText,
    required String initialContentIfMissing,
    VaultWatcher? watcher,
  }) async {
    final absPath = VaultPath(relPath).toAbsolute(vaultRootPath);
    final file = File(absPath);

    VaultFileContents existing;
    if (await file.exists()) {
      existing = await readVaultFile(file);
    } else {
      existing = VaultFileContents(
        text: initialContentIfMissing,
        hadBom: false,
      );
    }

    final doc = MarkdownDocument.parse(existing.text).appendLine(lineText);
    watcher?.suppressSelfWrite(VaultPath(absPath));
    await writeVaultFileAtomic(
      file,
      VaultFileContents(text: doc.rawText, hadBom: existing.hadBom),
    );
    return doc;
  }

  /// Applies a surgical [transform] to the [MarkdownDocument] at [relPath]
  /// and writes the result atomically to disk (`D-19`), preserving BOM and
  /// line endings.
  static Future<MarkdownDocument?> editVaultFileInPlace({
    required String vaultRootPath,
    required String relPath,
    required MarkdownDocument Function(MarkdownDocument doc) transform,
    VaultWatcher? watcher,
  }) async {
    final absPath = VaultPath(relPath).toAbsolute(vaultRootPath);
    final file = File(absPath);
    if (!await file.exists()) return null;

    final existing = await readVaultFile(file);
    final parsed = MarkdownDocument.parse(existing.text);
    final updated = transform(parsed);
    if (updated.rawText == parsed.rawText) return parsed;

    watcher?.suppressSelfWrite(VaultPath(absPath));
    await writeVaultFileAtomic(
      file,
      VaultFileContents(text: updated.rawText, hadBom: existing.hadBom),
    );
    return updated;
  }
}
