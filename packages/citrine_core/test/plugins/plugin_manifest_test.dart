import 'package:citrine_core/citrine_core.dart';
import 'package:test/test.dart';

void main() {
  group('PluginManifest & PluginPermission (PL-02, PL-03)', () {
    test('parses standard valid plugin.json manifest', () {
      final json = {
        'id': 'com.example.weather-context',
        'name': 'Weather Context',
        'version': '1.0.0',
        'description': 'Tags tasks with weather',
        'author': 'Jane Developer',
        'permissions': ['tasks:read', 'tasks:write', 'network:fetch'],
        'entry': 'dist/bundle.js',
      };

      final manifest = PluginManifest.fromJson(json);
      expect(manifest.id, equals('com.example.weather-context'));
      expect(manifest.name, equals('Weather Context'));
      expect(manifest.version, equals('1.0.0'));
      expect(manifest.description, equals('Tags tasks with weather'));
      expect(manifest.author, equals('Jane Developer'));
      expect(manifest.entry, equals('dist/bundle.js'));
      expect(
        manifest.permissions,
        equals({
          PluginPermission.tasksRead,
          PluginPermission.tasksWrite,
          PluginPermission.networkFetch,
        }),
      );

      final outJson = manifest.toJson();
      expect(outJson['id'], equals('com.example.weather-context'));
      expect(
        outJson['permissions'],
        containsAll(['tasks:read', 'tasks:write', 'network:fetch']),
      );
    });

    test('defaults entry to main.js and handles empty permissions gracefully', () {
      final json = {
        'id': 'minimal-plugin',
        'name': 'Minimal',
      };

      final manifest = PluginManifest.fromJson(json);
      expect(manifest.id, equals('minimal-plugin'));
      expect(manifest.entry, equals('main.js'));
      expect(manifest.permissions, isEmpty);
      expect(manifest.version, equals('0.1.0'));
    });

    test('rejects missing or invalid plugin id', () {
      expect(
        () => PluginManifest.fromJson({'name': 'No ID'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PluginManifest.fromJson({'id': 'bad id with spaces'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PluginManifest.fromJson({'id': 'bad/slashes'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('all PluginPermission enum values have unique IDs, labels, and descriptions', () {
      final ids = <String>{};
      for (final p in PluginPermission.values) {
        expect(p.id, isNotEmpty);
        expect(p.label, isNotEmpty);
        expect(p.description, isNotEmpty);
        expect(ids.add(p.id), isTrue, reason: 'Duplicate permission id: ${p.id}');
        expect(PluginPermission.tryParse(p.id), equals(p));
      }
      expect(PluginPermission.tryParse('non_existent:permission'), isNull);
    });
  });
}
