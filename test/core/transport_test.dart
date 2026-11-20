import 'package:uni_pulse/common/constant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows Core pipe uses a 128-bit random suffix', () {
    const prefix = r'\\.\pipe\UniPulseCore_';
    expect(windowsPipeName, startsWith(prefix));
    expect(
      windowsPipeName.substring(prefix.length),
      matches(RegExp(r'^[0-9a-f]{32}$')),
    );
  });
}
