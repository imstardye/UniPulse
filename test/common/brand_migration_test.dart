import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:uni_pulse/common/brand_migration.dart';

void main() {
  late Directory root;
  late Directory source;
  late Directory target;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('unipulse-migration-');
    source = await Directory(p.join(root.path, 'old')).create();
    target = await Directory(p.join(root.path, 'new')).create();
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'copies a database, preferences and profiles and preserves rollback data',
    () async {
      final database = sqlite3.open(p.join(source.path, 'database.sqlite'));
      database.execute('CREATE TABLE profiles (name TEXT)');
      database.execute("INSERT INTO profiles VALUES ('saved profile')");
      database.close();
      await File(
        p.join(source.path, 'shared_preferences.json'),
      ).writeAsString('{"flutter.config":"saved"}');
      await Directory(p.join(source.path, 'profiles')).create();
      await File(
        p.join(source.path, 'profiles', '1.yaml'),
      ).writeAsString('proxies: []');
      expect(await migrateLegacyDirectory(target.path, [source.path]), isTrue);
      final migrated = sqlite3.open(p.join(target.path, 'database.sqlite'));
      expect(
        migrated.select('SELECT name FROM profiles').single['name'],
        'saved profile',
      );
      migrated.close();
      for (final file in [
        'database.sqlite',
        'shared_preferences.json',
        'profiles/1.yaml',
      ]) {
        expect(
          await File(p.join(target.path, file)).readAsBytes(),
          await File(p.join(source.path, file)).readAsBytes(),
        );
      }
      expect(await migrateLegacyDirectory(target.path, [source.path]), isFalse);
    },
  );

  test('leaves an existing new installation untouched', () async {
    await File(p.join(source.path, 'database.sqlite')).writeAsString('old');
    await File(p.join(target.path, 'config.yaml')).writeAsString('new');
    expect(await migrateLegacyDirectory(target.path, [source.path]), isFalse);
    expect(
      await File(p.join(target.path, 'database.sqlite')).exists(),
      isFalse,
    );
    expect(
      await File(p.join(target.path, 'config.yaml')).readAsString(),
      'new',
    );
  });

  test('recovers an interrupted promotion before retrying', () async {
    await File(
      p.join(source.path, 'database.sqlite'),
    ).writeAsString('complete');
    await File(p.join(target.path, 'database.sqlite')).writeAsString('partial');
    await File(
      p.join(target.path, '.legacy-import-journal'),
    ).writeAsString('["database.sqlite"]');
    expect(await migrateLegacyDirectory(target.path, [source.path]), isTrue);
    expect(
      await File(p.join(target.path, 'database.sqlite')).readAsString(),
      'complete',
    );
  });

  test(
    'failed copies leave the original intact and publish no new files',
    () async {
      await File(p.join(source.path, 'database.sqlite')).writeAsString('old');
      await Link(p.join(source.path, 'external')).create(root.path);
      await expectLater(
        migrateLegacyDirectory(target.path, [source.path]),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File(p.join(target.path, 'database.sqlite')).exists(),
        isFalse,
      );
      expect(
        await File(p.join(source.path, 'database.sqlite')).readAsString(),
        'old',
      );
      expect(
        await Directory(p.join(target.path, '.legacy-import')).exists(),
        isFalse,
      );
    },
    skip: Platform.isWindows,
  );

  test('does not migrate runtime locks or spilled responses', () async {
    await File(p.join(source.path, 'config.yaml')).writeAsString('saved');
    await File(p.join(source.path, 'FlClash.lock')).writeAsString('');
    await Directory(p.join(source.path, 'responses')).create();
    expect(await migrateLegacyDirectory(target.path, [source.path]), isTrue);
    expect(await File(p.join(target.path, 'FlClash.lock')).exists(), isFalse);
    expect(await Directory(p.join(target.path, 'responses')).exists(), isFalse);
  });

  test('resolves platform data paths and separates debug installs', () {
    expect(
      legacyDataDirectories(
        r'C:\Users\example\AppData\Roaming\com.imstardye\unipulse',
        'windows',
      ),
      [r'C:\Users\example\AppData\Roaming\com.follow\clash'],
    );
    expect(
      legacyDataDirectories(
        '/example/Library/Application Support/com.imstardye.unipulse.debug',
        'macos',
      ),
      ['/example/Library/Application Support/com.follow.clash.debug'],
    );
    expect(
      legacyDataDirectories(
        '/example/.local/share/com.imstardye.unipulse',
        'linux',
      ),
      [
        '/example/.local/share/com.follow.clash',
        '/example/.local/share/FlClash',
      ],
    );
    expect(
      legacyDataDirectories(
        '/data/user/10/com.imstardye.unipulse.dev/files',
        'android',
      ),
      ['/data/user/10/com.follow.clash.dev/files'],
    );
  });

  test('imports macOS application preferences without unrelated defaults', () {
    expect(
      decodeLegacyPreferences(
        '{"flutter.config":"saved", "flutter.version":4, "AppleLocale":"en_US"}',
      ),
      {'config': 'saved', 'version': 4},
    );
  });

  test('imports Android preference types and XML escapes', () {
    expect(
      decodeAndroidLegacyPreferences(
        '<map><string name="flutter.config">a&amp;b</string><long name="flutter.version" value="4"/><boolean name="flutter.enabled" value="true"/></map>',
      ),
      {'config': 'a&b', 'version': 4, 'enabled': true},
    );
  });
}
