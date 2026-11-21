import 'dart:convert';
import 'dart:io';

import 'package:uni_pulse/common/release_asset.dart';
import 'package:path/path.dart' as p;

import 'manifest.dart';
import 'steps.dart';

const siteScript = 'site/assets/app.js';
const releaseNotesTemplate = '.github/release_template.md';
const homebrewCaskTemplate = '.github/homebrew_cask_template.rb';
const updaterSource = 'lib/common/app_update.dart';

typedef ReleaseLookup = ({String reader, String name});

List<String> siteAssetNames(String script, String version, ReleaseLine line) {
  final prefixes = RegExp(
    r"const prefixes = \['([^']+)', '([^']+)'\];",
  ).firstMatch(script);
  const naming = r'`${prefix}-${release.version}-${id}`';
  if (prefixes == null || !script.contains(naming)) {
    throw const PackageError('$siteScript has an unknown asset naming form');
  }
  final prefix = prefixes[line == ReleaseLine.rs ? 2 : 1]!;
  final ids = [
    for (final match in RegExp(
      r"\bid: (?:'([^']+)'|`([^`]+)`)",
    ).allMatches(script))
      match[1] ?? match[2]!,
    for (final match in RegExp(
      r"assetName\(release, '([^']+)'\)",
    ).allMatches(script))
      match[1]!,
  ];
  if (ids.isEmpty) throw const PackageError('$siteScript has no asset IDs');
  return [
    for (final id in ids)
      for (final arch
          in id.contains(r'${goArch(arch)}') ? ['amd64', 'arm64'] : [''])
        _placeholderFree(
          '$prefix-$version-${id.replaceAll(r'${goArch(arch)}', arch)}',
          siteScript,
        ),
  ];
}

List<String> releaseNotesAssetNames(
  String template,
  List<ManifestEntry> entries,
) {
  final names = [
    for (final match in RegExp(
      r'releases/download/\{\{TAG\}\}/([^"\s]+)',
    ).allMatches(template))
      _substitute(match[1]!, {
        for (final entry in entries)
          '${entry.os.name}-${entry.arch.name}-${p.extension(entry.name).substring(1)}':
              entry.name,
      }, releaseNotesTemplate),
  ];
  if (names.isEmpty) {
    throw const PackageError('$releaseNotesTemplate has no release links');
  }
  return names;
}

List<String> homebrewAssetNames(String cask, List<ManifestEntry> entries) {
  final url = RegExp(
    r'url "[^"\n]*/releases/download/\{\{TAG\}\}/([^"\n]+)"',
  ).firstMatch(cask);
  final arches = RegExp(
    r'arch arm: "([^"]+)", intel: "([^"]+)"',
  ).firstMatch(cask);
  if (url == null || arches == null) {
    throw const PackageError(
      '$homebrewCaskTemplate has no release URL or arches',
    );
  }
  final values = {
    for (final entry in entries)
      if (entry.os == ReleaseOs.macos && entry.name.endsWith('.dmg'))
        '${entry.arch == ReleaseArch.arm64 ? 'ARM' : 'AMD'}_DMG': entry.name,
  };
  return [
    for (final arch in [arches[1]!, arches[2]!])
      _substitute(
        url[1]!.replaceAll('#{arch}', arch),
        values,
        homebrewCaskTemplate,
      ),
  ];
}

List<String> updaterAssetNames(
  String source,
  String version,
  ReleaseLine line,
) {
  final compact = source.replaceAll(RegExp(r'\s+'), '');
  const assetNaming =
      'returnreleaseAssetName(line:appReleaseLine,'
      'version:releaseVersionOfTag(tag),os:asset.os,arch:asset.arch,'
      'form:asset.form,extension:asset.extension,);';
  const checksumsNaming =
      'returnreleaseChecksumsName(appReleaseLine,releaseVersionOfTag(tag));';
  for (final naming in [assetNaming, checksumsNaming]) {
    if (!compact.contains(naming)) {
      throw const PackageError(
        '$updaterSource has an unknown asset naming form',
      );
    }
  }
  final helpers = {
    for (final match in RegExp(
      r'SelfUpdateAsset (\w+)\(ReleaseArch arch\)\s*=>\s*\(([\s\S]*?)\);',
    ).allMatches(source))
      match[1]!: match[2]!,
  };
  final names = <String>{};
  for (final match in RegExp(
    r'Abi\.\w+(?: when windowsInstalled)?\s*=>\s*(\w+)\(ReleaseArch\.(\w+)\)',
  ).allMatches(source)) {
    final fields = helpers[match[1]];
    String field(String key) {
      final value = fields == null
          ? null
          : RegExp('$key: *([^,\n]+)').firstMatch(fields)?[1];
      if (value == null) {
        throw PackageError('$updaterSource has no $key for ${match[1]}');
      }
      return value.trim();
    }

    if (field('arch') != 'arch') {
      throw const PackageError(
        '$updaterSource has an unknown architecture form',
      );
    }
    final form = field('form');
    final extension = RegExp(r"^'([^']+)'$").firstMatch(field('extension'));
    if (extension == null) {
      throw const PackageError('$updaterSource has an unknown extension form');
    }
    names.add(
      releaseAssetName(
        line: line,
        version: version,
        os: ReleaseOs.values.byName(field('os').replaceFirst('ReleaseOs.', '')),
        arch: ReleaseArch.values.byName(match[2]!),
        form: form == 'null'
            ? null
            : ReleaseForm.values.byName(form.replaceFirst('ReleaseForm.', '')),
        extension: extension[1]!,
      ),
    );
  }
  if (names.isEmpty) {
    throw const PackageError('$updaterSource has no self-update assets');
  }
  return names.toList();
}

List<ReleaseLookup> releaseLookups(String root, List<ManifestEntry> entries) {
  final line = entries.first.line;
  final version = entries.first.version;
  String read(String relative) =>
      File(p.join(root, relative)).readAsStringSync();
  return [
    for (final name in siteAssetNames(read(siteScript), version, line))
      (reader: siteScript, name: name),
    for (final name in releaseNotesAssetNames(
      read(releaseNotesTemplate),
      entries,
    ))
      (reader: releaseNotesTemplate, name: name),
    for (final name in homebrewAssetNames(read(homebrewCaskTemplate), entries))
      (reader: homebrewCaskTemplate, name: name),
    for (final name in [
      ...updaterAssetNames(read(updaterSource), version, line),
      releaseChecksumsName(line, version),
    ])
      (reader: 'in-app updater', name: name),
  ];
}

List<String> releaseContractFailures(String root, String directory) {
  final entries = readManifest(directory);
  final releases = {for (final entry in entries) (entry.line, entry.version)};
  if (releases.length != 1) {
    throw PackageError('$directory must hold one release line and version');
  }
  final (line, version) = releases.single;
  final checksums = releaseChecksumsName(line, version);
  final listed = {for (final entry in entries) entry.name, checksums};
  final present = {
    for (final file in Directory(directory).listSync().whereType<File>())
      p.basename(file.path),
  };
  final failures = [
    for (final lookup in releaseLookups(root, entries))
      if (!listed.contains(lookup.name) || !present.contains(lookup.name))
        '${lookup.reader} looks for ${lookup.name}, which is missing',
  ];
  if (!present.contains(checksums)) return failures;
  final sums = const LineSplitter()
      .convert(File(p.join(directory, checksums)).readAsStringSync())
      .toSet();
  final digests = {for (final entry in entries) entry.name: entry.sha256};
  final source = File(p.join(root, updaterSource)).readAsStringSync();
  for (final name in updaterAssetNames(source, version, line)) {
    if (digests[name] != null && !sums.contains('${digests[name]}  $name')) {
      failures.add(
        'in-app updater finds no matching sha256 for $name in $checksums',
      );
    }
  }
  return failures;
}

String _substitute(String name, Map<String, String> values, String source) {
  return _placeholderFree(
    name.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (match) {
      final value = values[match[1]];
      if (value == null) {
        throw PackageError(
          '$source looks for ${match[0]}, which has no artifact',
        );
      }
      return value;
    }),
    source,
  );
}

String _placeholderFree(String name, String source) {
  if (RegExp(r'\$\{|#\{|\{\{|TAG|LINE').hasMatch(name)) {
    throw PackageError('$source names $name, with a placeholder left in it');
  }
  return name;
}
