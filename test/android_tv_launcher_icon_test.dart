import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

String _androidAttribute(String source, String element, String attribute) {
  final elementTag = RegExp('<$element\\b[^>]*>').firstMatch(source)!.group(0)!;
  return RegExp(
    'android:$attribute="([^"]+)"',
  ).firstMatch(elementTag)!.group(1)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TV launcher icons meet density-specific minimum sizes', () async {
    const expectedSizes = {
      'mdpi': 80,
      'hdpi': 120,
      'xhdpi': 160,
      'xxhdpi': 240,
      'xxxhdpi': 320,
    };

    for (final MapEntry(key: density, value: size) in expectedSizes.entries) {
      final file = File(
        'android/app/src/main/res/'
        'mipmap-television-$density/ic_launcher.webp',
      );
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');

      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      expect(
        (frame.image.width, frame.image.height),
        (size, size),
        reason: file.path,
      );
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('TV adaptive launcher icon stays centered in the safe zone', () async {
    final adaptiveIcon = File(
      'android/app/src/main/res/'
      'mipmap-television-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(
      _androidAttribute(adaptiveIcon, 'foreground', 'drawable'),
      '@mipmap/ic_launcher_foreground',
    );
    expect(
      _androidAttribute(adaptiveIcon, 'background', 'drawable'),
      '@android:color/transparent',
    );

    const canvasSize = 432;
    final foreground = File(
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png',
    );
    final codec = await ui.instantiateImageCodec(
      await foreground.readAsBytes(),
    );
    addTearDown(codec.dispose);
    final image = (await codec.getNextFrame()).image;
    addTearDown(image.dispose);
    expect((image.width, image.height), (canvasSize, canvasSize));

    final pixels = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    var alphaLeft = canvasSize;
    var alphaTop = canvasSize;
    var alphaRight = 0;
    var alphaBottom = 0;
    var logoLeft = canvasSize;
    var logoTop = canvasSize;
    var logoRight = 0;
    var logoBottom = 0;
    for (var y = 0; y < canvasSize; y++) {
      for (var x = 0; x < canvasSize; x++) {
        final offset = (y * canvasSize + x) * 4;
        final alpha = pixels.getUint8(offset + 3);
        if (alpha == 0) continue;
        if (x < alphaLeft) alphaLeft = x;
        if (y < alphaTop) alphaTop = y;
        if (x + 1 > alphaRight) alphaRight = x + 1;
        if (y + 1 > alphaBottom) alphaBottom = y + 1;
        if (x < logoLeft) logoLeft = x;
        if (y < logoTop) logoTop = y;
        if (x + 1 > logoRight) logoRight = x + 1;
        if (y + 1 > logoBottom) logoBottom = y + 1;
      }
    }
    final alphaBounds = ui.Rect.fromLTRB(
      alphaLeft.toDouble(),
      alphaTop.toDouble(),
      alphaRight.toDouble(),
      alphaBottom.toDouble(),
    );
    final logoBounds = ui.Rect.fromLTRB(
      logoLeft.toDouble(),
      logoTop.toDouble(),
      logoRight.toDouble(),
      logoBottom.toDouble(),
    );
    expect(
      alphaBounds.isEmpty,
      isFalse,
      reason: 'foreground is fully transparent',
    );
    expect(logoBounds.isEmpty, isFalse, reason: 'foreground mark is missing');

    const pixelsPerDp = canvasSize / 108;
    const safeZone = ui.Rect.fromLTRB(
      18 * pixelsPerDp,
      18 * pixelsPerDp,
      90 * pixelsPerDp,
      90 * pixelsPerDp,
    );
    expect(logoBounds.left, greaterThanOrEqualTo(safeZone.left));
    expect(logoBounds.top, greaterThanOrEqualTo(safeZone.top));
    expect(logoBounds.right, lessThanOrEqualTo(safeZone.right));
    expect(logoBounds.bottom, lessThanOrEqualTo(safeZone.bottom));

    const centerTolerance = 3;
    expect(alphaBounds.center.dx, closeTo(canvasSize / 2, centerTolerance));
    expect(alphaBounds.center.dy, closeTo(canvasSize / 2, centerTolerance));
  });
}
