import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:uni_pulse/common/app_update.dart';
import 'package:uni_pulse/common/release_asset.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/package.dart' as package;
import '../../tool/src/package/context.dart';
import '../../tool/src/package/manifest.dart';
import '../../tool/src/package/release_contract.dart';
import '../../tool/src/package/steps.dart';

const _version = '0.9.7';

String _read(String relative) => File(relative).readAsStringSync();

List<YamlMap> _matrix() {
  final workflow = loadYaml(_read('.github/workflows/build.yaml')) as YamlMap;
  return (workflow['jobs']['build']['strategy']['matrix']['include']
          as YamlList)
      .cast<YamlMap>();
}

String _rowName(YamlMap row) => '${row['platform']}-${row['arch'] ?? 'all'}';

Future<Map<String, List<String>>> _writeRelease(
  String directory,
  ReleaseLine line,
) async {
  final inputs = <String>[];
  final byRow = <String, List<String>>{};
  for (final row in _matrix()) {
    final os = ReleaseOs.values.byName(row['platform'] as String);
    final rowName = _rowName(row);
    final output = p.join(directory, rowName);
    Directory(output).createSync(recursive: true);
    inputs.add(output);
    final context = PackageContext(
      root: Directory.current.path,
      os: os,
      arch: os == ReleaseOs.android
          ? ReleaseArch.universal
          : ReleaseArch.values.byName(row['arch'] as String),
      line: line,
      version: _version,
      channel: 'stable',
      commit: 'c' * 40,
      pubspecVersion: '$_version+1',
      description: '',
      outputDirectory: output,
    );
    final entries = <ManifestEntry>[];
    for (final target in package.defaultTargets[os]!) {
      final plan = package.planTarget(
        context,
        target,
        androidArches: const [
          ReleaseArch.arm64,
          ReleaseArch.armv7,
          ReleaseArch.amd64,
        ],
      );
      for (final artifact in plan.artifacts) {
        File(
          context.outputPath(artifact.name),
        ).writeAsStringSync(artifact.name);
        entries.add(await describeArtifact(context, artifact));
      }
    }
    writeManifest(output, entries);
    byRow[rowName] = [for (final entry in entries) entry.name];
  }
  await mergeManifests(inputs, p.join(directory, 'dist'));
  return byRow;
}

const _suffixes = [
  'android-arm64.apk',
  'android-armv7.apk',
  'android-amd64.apk',
  'windows-amd64-setup.exe',
  'windows-arm64-setup.exe',
  'windows-amd64-portable.zip',
  'windows-arm64-portable.zip',
  'macos-arm64.dmg',
  'macos-amd64.dmg',
  'linux-amd64.deb',
  'linux-arm64.deb',
  'linux-amd64.rpm',
  'linux-arm64.rpm',
  'linux-amd64.AppImage',
  'linux-arm64.AppImage',
];

void main() {
  test('uses all seven build combinations', () {
    expect(
      _matrix().map(_rowName),
      unorderedEquals([
        'android-all',
        'windows-amd64',
        'windows-arm64',
        'linux-amd64',
        'linux-arm64',
        'macos-amd64',
        'macos-arm64',
      ]),
    );
  });

  test('refuses unknown site and updater naming forms', () {
    expect(
      () => siteAssetNames(
        _read(siteScript).replaceFirst('macos-arm64.dmg', r'macos-${arch}.dmg'),
        _version,
        ReleaseLine.dev,
      ),
      throwsA(isA<PackageError>()),
    );
    expect(
      () => updaterAssetNames(
        _read(
          updaterSource,
        ).replaceFirst('version: releaseVersionOfTag(tag)', "version: '1.0.0'"),
        _version,
        ReleaseLine.dev,
      ),
      throwsA(isA<PackageError>()),
    );
  });

  test(
    'site keeps missing downloads visible and links to the release page',
    () {
      final script = _read(siteScript);
      final functions = script.substring(
        script.indexOf('  function goArch('),
        script.indexOf('  async function detectDevice('),
      );
      final result = Process.runSync('node', [
        '-e',
        '''
const REPO = 'https://github.com/imstardye/UniPulse';
const state = {};
const t = (key) => key;
$functions
for (const prefix of ['UniPulse', 'UniPulse-rs']) {
  const name = prefix + '-$_version-android-arm64.apk';
  state.release = {version: '$_version', tag: 'v$_version', assets: new Map([[name, {size: 10}]])};
  const builds = resolveBuilds('android', 'arm64');
  if (builds.length !== 3 || !builds[0].href.endsWith('/' + name) ||
      !builds[1].href.endsWith('/releases/tag/v$_version') ||
      !assetHref(state.release, assetName(state.release, 'SHA256SUMS')).endsWith('/releases/tag/v$_version')) process.exit(1);
}
state.release = {version: '$_version', tag: 'v$_version', assets: null};
if (!resolveBuilds('android', 'arm64')[0].href.endsWith('/UniPulse-$_version-android-arm64.apk')) process.exit(1);
''',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );

  for (final line in ReleaseLine.values) {
    group('${line.name} release built by the CI matrix', () {
      late Directory temp;
      late String dist;
      late Map<String, List<String>> byRow;
      late List<ManifestEntry> entries;
      final prefix = line == ReleaseLine.rs ? 'UniPulse-rs' : 'UniPulse';

      setUp(() async {
        temp = Directory.systemTemp.createTempSync('release_contract');
        dist = p.join(temp.path, 'dist');
        byRow = await _writeRelease(temp.path, line);
        entries = readManifest(dist);
      });
      tearDown(() => temp.deleteSync(recursive: true));

      test('serves all four readers with the existing line-specific names', () {
        expect(siteAssetNames(_read(siteScript), _version, line), [
          for (final suffix in [..._suffixes, 'SHA256SUMS'])
            '$prefix-$_version-$suffix',
        ]);
        expect(
          releaseNotesAssetNames(_read(releaseNotesTemplate), entries),
          unorderedEquals([
            for (final suffix in _suffixes) '$prefix-$_version-$suffix',
          ]),
        );
        expect(homebrewAssetNames(_read(homebrewCaskTemplate), entries), [
          '$prefix-$_version-macos-arm64.dmg',
          '$prefix-$_version-macos-amd64.dmg',
        ]);
        final expectedUpdater = {
          for (final abi in Abi.values)
            if (selfUpdateAssetFor(abi, windowsInstalled: true)
                case final asset?)
              releaseAssetName(
                line: line,
                version: _version,
                os: asset.os,
                arch: asset.arch,
                form: asset.form,
                extension: asset.extension,
              ),
        };
        expect(expectedUpdater, hasLength(5));
        expect(
          updaterAssetNames(_read(updaterSource), _version, line),
          unorderedEquals(expectedUpdater),
        );
        expect(releaseContractFailures(Directory.current.path, dist), isEmpty);
      });

      for (final row in _matrix()) {
        test('checks every artifact of ${_rowName(row)}', () {
          expect(
            releaseContractFailures(Directory.current.path, dist),
            isEmpty,
          );
          for (final name in byRow[_rowName(row)]!) {
            final file = File(p.join(dist, name));
            file.deleteSync();
            expect(
              releaseContractFailures(Directory.current.path, dist),
              contains('$siteScript looks for $name, which is missing'),
            );
            file.writeAsStringSync(name);
          }
        });
      }

      test('names each reader of a missing installer', () {
        final name = '$prefix-$_version-windows-arm64-setup.exe';
        File(p.join(dist, name)).deleteSync();
        expect(releaseContractFailures(Directory.current.path, dist), [
          '$siteScript looks for $name, which is missing',
          '$releaseNotesTemplate looks for $name, which is missing',
          'in-app updater looks for $name, which is missing',
        ]);
      });

      test('refuses unresolved release and Homebrew placeholders', () {
        expect(
          () => releaseNotesAssetNames(
            _read(
              releaseNotesTemplate,
            ).replaceFirst('android-arm64-apk', 'android-missing-apk'),
            entries,
          ),
          throwsA(isA<PackageError>()),
        );
        expect(
          () => homebrewAssetNames(
            _read(
              homebrewCaskTemplate,
            ).replaceFirst('{{ARM_DMG}}', '{{UNKNOWN_DMG}}'),
            entries,
          ),
          throwsA(isA<PackageError>()),
        );
      });

      test('checks both presence and manifest membership', () {
        File(p.join(dist, 'manifest.json')).writeAsStringSync(
          jsonEncode({
            'artifacts': [for (final entry in entries.skip(1)) entry.toJson()],
          }),
        );
        expect(
          () => releaseContractFailures(Directory.current.path, dist),
          throwsA(isA<PackageError>()),
        );
      });

      test('catches a checksum file that misstates an installer', () {
        final checksums = releaseChecksumsName(line, _version);
        final sums = File(p.join(dist, checksums));
        sums.writeAsStringSync(
          sums.readAsStringSync().replaceFirst(
            RegExp(r'[0-9a-f]{64}'),
            '0' * 64,
          ),
        );
        final name = entries.first.name;
        expect(releaseContractFailures(Directory.current.path, dist), [
          'in-app updater finds no matching sha256 for $name in $checksums',
        ]);
      });

      test('requires the checksum file for the site and updater', () {
        final checksums = releaseChecksumsName(line, _version);
        File(p.join(dist, checksums)).deleteSync();
        expect(releaseContractFailures(Directory.current.path, dist), [
          '$siteScript looks for $checksums, which is missing',
          'in-app updater looks for $checksums, which is missing',
        ]);
      });
    });
  }
}
