import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/presentation/widgets/ui/thumbnail_image.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

void main() {
  testWidgets('renders the image once the bytes arrive', (tester) async {
    await pumpComponent(
      tester,
      ThumbnailImage(bytes: AsyncValue<Uint8List?>.data(testPngBytes)),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('null bytes render the broken-image fallback', (tester) async {
    await pumpComponent(
      tester,
      const ThumbnailImage(bytes: AsyncValue<Uint8List?>.data(null)),
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('an error renders the broken-image fallback too', (tester) async {
    await pumpComponent(
      tester,
      ThumbnailImage(
        bytes: AsyncValue<Uint8List?>.error(
          Exception('boom'),
          StackTrace.empty,
        ),
      ),
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('loading renders a spinner', (tester) async {
    await pumpComponent(
      tester,
      const ThumbnailImage(bytes: AsyncValue<Uint8List?>.loading()),
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
