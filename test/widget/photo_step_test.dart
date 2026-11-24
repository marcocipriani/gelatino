import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/screens/check_in/photo_step.dart';

void main() {
  Widget step({required bool uploading, double? progress}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PhotoStep(
          bytes: null,
          hasStagedPhoto: false,
          isUploading: uploading,
          uploadProgress: progress,
          photoMissing: false,
          uploadFailed: false,
          onCamera: null,
          onGallery: null,
          onRemove: null,
          onRetry: () {},
          onRetryUpload: () {},
        ),
      ),
    ),
  );

  testWidgets('shows determinate progress once bytes are moving', (
    tester,
  ) async {
    await tester.pumpWidget(step(uploading: true, progress: 0.42));

    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey<String>('check-in-upload-progress')),
    );
    expect(bar.value, 0.42);
    expect(find.text('Caricamento privato… 42%'), findsOneWidget);
  });

  testWidgets('falls back to the compression spinner without progress', (
    tester,
  ) async {
    await tester.pumpWidget(step(uploading: true));

    expect(find.text('Compressione e caricamento privato…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
