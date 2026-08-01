import 'package:citrinium_core/parser.dart';
import 'package:test/test.dart';

void main() {
  group('taskStateKindForMarker', () {
    final known = {
      ' ': TaskStateKind.open,
      '/': TaskStateKind.inProgress,
      'x': TaskStateKind.completed,
      'X': TaskStateKind.completed,
      '>': TaskStateKind.migrated,
      '<': TaskStateKind.scheduled,
      '-': TaskStateKind.dropped,
      'w': TaskStateKind.waitingFor,
      'W': TaskStateKind.waitingFor,
    };

    known.forEach((marker, kind) {
      test('"$marker" maps to $kind', () {
        expect(taskStateKindForMarker(marker), kind);
      });
    });

    for (final marker in ['?', '!', 'i', '~', '@']) {
      test('unrecognized marker "$marker" maps to unknown', () {
        expect(taskStateKindForMarker(marker), TaskStateKind.unknown);
      });
    }
  });

  group('canonicalMarkerFor', () {
    test('round-trips every known state through taskStateKindForMarker', () {
      for (final kind in TaskStateKind.values) {
        if (kind == TaskStateKind.unknown) continue;
        final marker = canonicalMarkerFor(kind);
        expect(taskStateKindForMarker(marker), kind);
      }
    });

    test('throws for TaskStateKind.unknown', () {
      expect(
        () => canonicalMarkerFor(TaskStateKind.unknown),
        throwsArgumentError,
      );
    });
  });
}
