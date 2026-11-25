import 'package:uni_pulse/main.dart';
import 'package:uni_pulse/pages/error.dart';
import 'package:uni_pulse/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a startup failure is logged with its stack trace', () {
    final printed = <String>[];
    final original = debugPrint;
    final attached = globalState.isAttach;
    globalState.isAttach = false;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    addTearDown(() {
      debugPrint = original;
      globalState.isAttach = attached;
    });
    final error = StateError('boot failed');
    final stack = StackTrace.fromString(
      '#0 boot (package:uni_pulse/main.dart:1)',
    );

    final app = initFailureApp(error, stack);

    expect(app, isA<InitErrorApp>().having((app) => app.error, 'error', error));
    expect(printed, [
      allOf(
        startsWith('[APP] Startup failed: $error'),
        contains('package:uni_pulse/main.dart:1'),
      ),
    ]);
  });
}
