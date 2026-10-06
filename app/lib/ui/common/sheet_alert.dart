import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

enum SheetAlertSeverity { error, warning }

@immutable
class SheetAlertData {
  const SheetAlertData({
    required this.message,
    required this.severity,
    this.actionLabel,
  });

  final String message;

  final SheetAlertSeverity severity;

  final String? actionLabel;

  @override
  bool operator ==(Object other) =>
      other is SheetAlertData &&
      message == other.message &&
      severity == other.severity &&
      actionLabel == other.actionLabel;

  @override
  int get hashCode => Object.hash(message, severity, actionLabel);
}

class SheetAlert extends StatelessWidget {
  const SheetAlert({super.key, required this.data, this.onAction});

  final SheetAlertData data;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (data.severity) {
      SheetAlertSeverity.error => (colors.errorBg, colors.error),
      SheetAlertSeverity.warning => (colors.noticeBg, colors.notice),
    };
    final actionLabel = data.actionLabel;
    final onAction = this.onAction;
    final message = Text(
      data.message,
      style: TextStyle(color: foreground, fontSize: 12, height: 1.45),
    );
    final action = actionLabel != null && onAction != null
        ? _BannerAction(label: actionLabel, onPressed: onAction)
        : null;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        message,
        if (action != null) ...[const SizedBox(height: 8), action],
      ],
    );
    final decoration = BoxDecoration(
      color: background,
      border: Border.all(color: foreground),
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    );

    return Semantics(
      liveRegion: true,
      child: Container(
        decoration: decoration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: content,
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({required this.label, required this.onPressed});

  final String label;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}
