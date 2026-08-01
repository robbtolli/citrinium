import 'package:citrinium_core/parser.dart';
import 'package:test/test.dart';

void main() {
  group('Span', () {
    test('of() extracts the exact substring', () {
      const source = 'hello world';
      expect(const Span(0, 5).of(source), 'hello');
      expect(const Span(6, 11).of(source), 'world');
    });

    test('length and isEmpty', () {
      expect(const Span(3, 3).isEmpty, isTrue);
      expect(const Span(3, 3).length, 0);
      expect(const Span(3, 4).isNotEmpty, isTrue);
      expect(const Span(3, 4).length, 1);
    });

    test('overlaps detects overlapping and non-overlapping ranges', () {
      expect(const Span(0, 5).overlaps(const Span(4, 10)), isTrue);
      expect(const Span(0, 5).overlaps(const Span(5, 10)), isFalse);
      expect(const Span(0, 5).overlaps(const Span(10, 20)), isFalse);
    });

    test('contains', () {
      expect(const Span(0, 5).contains(0), isTrue);
      expect(const Span(0, 5).contains(4), isTrue);
      expect(const Span(0, 5).contains(5), isFalse);
    });

    test('shift moves both ends', () {
      expect(const Span(2, 5).shift(3), const Span(5, 8));
      expect(const Span(5, 8).shift(-2), const Span(3, 6));
    });

    test('equality and hashCode are value-based', () {
      expect(const Span(1, 2), const Span(1, 2));
      expect(const Span(1, 2).hashCode, const Span(1, 2).hashCode);
      expect(const Span(1, 2), isNot(const Span(1, 3)));
    });

    test('asserts end >= start', () {
      expect(() => Span(5, 2), throwsA(isA<AssertionError>()));
    });
  });
}
