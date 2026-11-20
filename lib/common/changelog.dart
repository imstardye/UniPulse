import 'dart:convert';

import 'package:uni_pulse/enum/enum.dart';
import 'package:uni_pulse/l10n/l10n.dart';
import 'package:uni_pulse/models/changelog.dart';

import 'common.dart';

const releaseChangelogJsonMarker = '<!-- unipulse:changelog:json';

const _releaseChangelogJsonEndMarker = '-->';

String changelogGroupTitle(
  AppLocalizations appLocalizations,
  ChangelogType type,
) => switch (type) {
  ChangelogType.breaking => appLocalizations.changelogBreaking,
  ChangelogType.feat => appLocalizations.changelogFeatures,
  ChangelogType.fix => appLocalizations.changelogFixes,
  ChangelogType.perf => appLocalizations.changelogPerformance,
  ChangelogType.revert => appLocalizations.changelogReverts,
  ChangelogType.unknown => '',
};

ChangelogVersion? parseReleaseChangelog(String? body) {
  if (body == null) {
    return null;
  }
  final marker = body.contains(releaseChangelogJsonMarker)
      ? releaseChangelogJsonMarker
      : '<!-- flclash:changelog:json';
  final begin = body.indexOf(marker);
  if (begin < 0) {
    return null;
  }
  final start = begin + marker.length;
  final end = body.indexOf(_releaseChangelogJsonEndMarker, start);
  if (end < 0) {
    return null;
  }
  try {
    final changelog = Changelog.fromJson(
      jsonDecode(body.substring(start, end)) as Map<String, dynamic>,
    );
    if (!changelog.isSupported) {
      commonPrint.log(
        'changelog schema ${changelog.schemaVersion} is not supported',
        logLevel: LogLevel.warning,
      );
      return null;
    }
    return changelog.versions.firstOrNull;
  } catch (error) {
    commonPrint.log(
      'changelog decode failed ${compactError(error)}',
      logLevel: LogLevel.warning,
    );
    return null;
  }
}
