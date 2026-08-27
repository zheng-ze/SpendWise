import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/web/chrome_prompt_api_availability.dart';

void main() {
  test(
    'is false off the web, even if the model would report available',
    () async {
      final result = await isChromePromptApiAvailable(
        isWeb: false,
        checkAvailability: () async => PromptApiAvailability.available,
      );

      expect(result, isFalse);
    },
  );

  test('is true on the web when the model is downloaded and ready', () async {
    final result = await isChromePromptApiAvailable(
      isWeb: true,
      checkAvailability: () async => PromptApiAvailability.available,
    );

    expect(result, isTrue);
  });

  test(
    'is false when the API is present but the model is downloadable',
    () async {
      final result = await isChromePromptApiAvailable(
        isWeb: true,
        checkAvailability: () async => PromptApiAvailability.downloadable,
        triggerDownload: () async {},
      );

      expect(result, isFalse);
    },
  );

  test('starts the download when the model is downloadable', () async {
    var triggered = false;

    await isChromePromptApiAvailable(
      isWeb: true,
      checkAvailability: () async => PromptApiAvailability.downloadable,
      triggerDownload: () async => triggered = true,
    );

    expect(triggered, isTrue);
  });

  test('does not start a download when the model is already available', () async {
    await isChromePromptApiAvailable(
      isWeb: true,
      checkAvailability: () async => PromptApiAvailability.available,
      triggerDownload: () async => fail('should not be called'),
    );
  });

  test('does not start a download while one is already in progress', () async {
    await isChromePromptApiAvailable(
      isWeb: true,
      checkAvailability: () async => PromptApiAvailability.downloading,
      triggerDownload: () async => fail('should not be called'),
    );
  });

  test('is false when the model is mid-download', () async {
    final result = await isChromePromptApiAvailable(
      isWeb: true,
      checkAvailability: () async => PromptApiAvailability.downloading,
    );

    expect(result, isFalse);
  });

  test('is false when the browser reports the API unavailable', () async {
    final result = await isChromePromptApiAvailable(
      isWeb: true,
      checkAvailability: () async => PromptApiAvailability.unavailable,
    );

    expect(result, isFalse);
  });
}
