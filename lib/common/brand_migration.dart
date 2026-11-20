import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

const _migrationMarker = '.unipulse-migrated';
const _persistentEntries = [
  'database.sqlite',
  'shared_preferences.json',
  'config.yaml',
  'profiles',
  'scripts',
  'mitm',
];

List<String> legacyDataDirectories(String destination, String os) {
  final paths = p.Context(
    style: os == 'windows' ? p.Style.windows : p.Style.posix,
  );
  final parent = paths.dirname(destination);
  return switch (os) {
    'windows' => [paths.join(paths.dirname(parent), 'com.follow', 'clash')],
    'linux' => [
      paths.join(parent, 'com.follow.clash'),
      paths.join(parent, 'FlClash'),
    ],
    'macos' => [
      paths.join(
        parent,
        destination.endsWith('.debug')
            ? 'com.follow.clash.debug'
            : 'com.follow.clash',
      ),
    ],
    'android' => [
      paths.join(
        paths.dirname(parent),
        paths.basename(parent).endsWith('.dev')
            ? 'com.follow.clash.dev'
            : 'com.follow.clash',
        'files',
      ),
    ],
    _ => [],
  };
}

Future<bool> migrateLegacyDirectory(String destination, List<String> sources) {
  return Isolate.run(() => _copyLegacyDirectory(destination, sources));
}

Future<bool> _copyLegacyDirectory(
  String destination,
  List<String> sources,
) async {
  if (await File(p.join(destination, _migrationMarker)).exists()) return false;
  final journal = File(p.join(destination, '.legacy-import-journal'));
  if (await journal.exists()) {
    final names = (jsonDecode(await journal.readAsString()) as List)
        .cast<String>();
    for (final name in names) {
      if (p.basename(name) != name || name.startsWith('.')) {
        throw const FormatException('Invalid legacy migration journal');
      }
      final target = p.join(destination, name);
      final type = await FileSystemEntity.type(target, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(target).delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        await File(target).delete();
      }
    }
    await journal.delete();
  }
  for (final name in _persistentEntries) {
    if (await FileSystemEntity.type(p.join(destination, name)) !=
        FileSystemEntityType.notFound) {
      return false;
    }
  }
  for (final source in sources) {
    if (!await Directory(source).exists()) continue;
    final entries = await Directory(source).list(followLinks: false).toList();
    if (!entries.any(
      (entry) => _persistentEntries.contains(p.basename(entry.path)),
    )) {
      continue;
    }
    final lock = await File(
      p.join(source, 'FlClash.lock'),
    ).open(mode: FileMode.append);
    final staging = Directory(p.join(destination, '.legacy-import'));
    final promoted = <FileSystemEntity>[];
    var committed = false;
    try {
      await lock.lock();
      if (await staging.exists()) await staging.delete(recursive: true);
      await staging.create(recursive: true);
      for (final entry in entries) {
        final name = p.basename(entry.path);
        if (name.endsWith('.lock') ||
            name == 'responses' ||
            name.startsWith('.')) {
          continue;
        }
        await _copyVerified(entry, p.join(staging.path, name));
      }
      final staged = await staging.list().toList();
      await _writeJournal(journal, []);
      for (final entry in staged) {
        final target = p.join(destination, p.basename(entry.path));
        if (await FileSystemEntity.type(target) !=
            FileSystemEntityType.notFound) {
          throw FileSystemException(
            'Migration destination already exists',
            target,
          );
        }
        await _writeJournal(journal, [
          ...promoted.map((item) => p.basename(item.path)),
          p.basename(entry.path),
        ]);
        promoted.add(await entry.rename(target));
      }
      await File(
        p.join(destination, _migrationMarker),
      ).writeAsString('1\n', flush: true);
      committed = true;
      await journal.delete();
      return true;
    } catch (_) {
      if (committed) rethrow;
      for (final entry in promoted.reversed) {
        await entry.delete(recursive: true);
      }
      if (await journal.exists()) await journal.delete();
      rethrow;
    } finally {
      await lock.close();
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }
  return false;
}

Future<void> _writeJournal(File journal, List<String> names) async {
  final pending = File('${journal.path}.next');
  await pending.writeAsString(jsonEncode(names), flush: true);
  await pending.rename(journal.path);
}

Future<void> _copyVerified(FileSystemEntity source, String destination) async {
  if (source is Directory) {
    await Directory(destination).create();
    await for (final entry in source.list(followLinks: false)) {
      await _copyVerified(entry, p.join(destination, p.basename(entry.path)));
    }
  } else if (source is File) {
    final copy = await source.copy(destination);
    final originalHash = await sha256.bind(source.openRead()).first;
    final copiedHash = await sha256.bind(copy.openRead()).first;
    if (originalHash != copiedHash) {
      throw FileSystemException('Legacy data verification failed', source.path);
    }
  } else {
    throw FileSystemException(
      'Legacy data contains a symbolic link',
      source.path,
    );
  }
}

Future<void> migrateBrandData(String destination) async {
  final os = Platform.operatingSystem;
  final sources = legacyDataDirectories(destination, os);
  if (os == 'linux' || os == 'windows') {
    await migrateLegacyDirectory(destination, sources);
    return;
  }
  if (sources.isEmpty) return;
  final store = await SharedPreferences.getInstance();
  if (store.containsKey('config') &&
      !await File(p.join(destination, '.legacy-import-journal')).exists()) {
    return;
  }
  Map<String, Object?> oldPreferences = {};
  if (os == 'android') {
    final legacy = File(
      p.join(
        p.dirname(sources.single),
        'shared_prefs',
        'FlutterSharedPreferences.xml',
      ),
    );
    if (await legacy.exists()) {
      oldPreferences = decodeAndroidLegacyPreferences(
        await legacy.readAsString(),
      );
    }
  }
  if (os == 'macos') {
    final domain = destination.endsWith('.debug')
        ? 'com.follow.clash.debug'
        : 'com.follow.clash';
    final result = await Process.run('/usr/bin/defaults', [
      'export',
      domain,
      '-',
    ]);
    if (result.exitCode == 0) {
      final process = await Process.start('/usr/bin/plutil', [
        '-convert',
        'json',
        '-o',
        '-',
        '--',
        '-',
      ]);
      process.stdin.write(result.stdout);
      await process.stdin.close();
      final output = await process.stdout.transform(utf8.decoder).join();
      if (await process.exitCode != 0) {
        throw const FileSystemException('Cannot decode legacy preferences');
      }
      oldPreferences = decodeLegacyPreferences(output);
    }
  }
  final migrated = await migrateLegacyDirectory(destination, sources);
  if (!migrated &&
      !await File(p.join(destination, _migrationMarker)).exists()) {
    return;
  }
  await store.reload();
  for (final entry in oldPreferences.entries) {
    final value = entry.value;
    if (store.containsKey(entry.key)) continue;
    switch (value) {
      case String():
        await store.setString(entry.key, value);
      case bool():
        await store.setBool(entry.key, value);
      case int():
        await store.setInt(entry.key, value);
      case double():
        await store.setDouble(entry.key, value);
      case List():
        await store.setStringList(entry.key, value.cast<String>());
    }
  }
}

Map<String, Object?> decodeLegacyPreferences(String source) {
  final values = jsonDecode(source) as Map<String, dynamic>;
  return {
    for (final entry in values.entries)
      if (entry.key.startsWith('flutter.')) entry.key.substring(8): entry.value,
  };
}

Map<String, Object?> decodeAndroidLegacyPreferences(String source) {
  final document = XmlDocument.parse(source);
  return {
    for (final element in document.rootElement.childElements)
      if (element.getAttribute('name') case final String name
          when name.startsWith('flutter.'))
        name.substring(8): switch (element.name.local) {
          'string' => element.innerText,
          'boolean' => element.getAttribute('value') == 'true',
          'int' || 'long' => int.parse(element.getAttribute('value')!),
          'float' => double.parse(element.getAttribute('value')!),
          'set' => element.childElements.map((item) => item.innerText).toList(),
          _ => throw FormatException(
            'Unsupported preference',
            element.name.local,
          ),
        },
  };
}
