part of '../sync_enrollment_screens.dart';

// MARK: - Error Text

class SyncEnrollmentErrorText extends StatelessWidget {
  const SyncEnrollmentErrorText({super.key, required this.message});

  final String message;

  static const _errorPadding = EdgeInsets.fromLTRB(16, 8, 16, 0);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: _errorPadding,
      child: Text(message, style: TextStyle(color: colors.error)),
    );
  }
}
