import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/ui/common/feedback/inline_spinner.dart';
import 'package:spendwise/ui/common/feedback/load_error_view.dart';
import 'package:spendwise/ui/common/navigation/page_header.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';

part 'screens/identifier_screen.dart';
part 'screens/otp_screen.dart';
part 'screens/resume_screen.dart';
part 'screens/completion_screen.dart';
part 'screens/enrollment_error_text.dart';

// MARK: - Shared Screen Values

int _ceilCooldownSeconds(Duration remaining) {
  final seconds = (remaining.inMilliseconds / 1000).ceil();
  return seconds < 1 ? 1 : seconds;
}

const _cooldownTick = Duration(seconds: 1);
const _screenPadding = EdgeInsets.all(16);
const _sectionSpacing = 16.0;
const _notePadding = EdgeInsets.only(top: 12);
