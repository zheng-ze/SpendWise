import 'package:decimal/decimal.dart';

/// Reads the merchant name and total amount out of a receipt's recognized
/// text. [FieldExtractionFailure] signals a real failure to run; a receipt
/// with no readable name or amount returns `null` instead of throwing.
// Device eligibility is decided by the function that selects and
// constructs an extractor, not by the extractor itself.
abstract class FieldExtractor {
  /// Throws [FieldExtractionFailure] if the engine can't run.
  /// [readingOrderText] is the receipt's recognized lines joined into one
  /// block of text in top-to-bottom, left-to-right reading order.
  Future<String?> extractName(String readingOrderText);

  /// Throws [FieldExtractionFailure] if the engine can't run.
  /// [readingOrderText] is the receipt's recognized lines joined into one
  /// block of text in top-to-bottom, left-to-right reading order.
  Future<Decimal?> extractAmount(String readingOrderText);

  /// Releases whatever resource the engine holds. The caller owns this
  /// extractor's lifetime and must call this when done with it.
  Future<void> dispose();
}
