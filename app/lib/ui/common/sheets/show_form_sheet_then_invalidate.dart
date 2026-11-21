import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';

// MARK: - showFormSheetThenInvalidate
Future<void> showFormSheetThenInvalidate({
  required BuildContext context,
  required ProviderContainer container,
  required ProviderOrFamily draftProvider,
  required WidgetBuilder builder,
}) async {
  AppSheetRoute<void>? route;
  await showAppSheet<void>(
    context,
    presentation: shellSheetPresentation(context),
    presentationResolver: shellSheetPresentation,
    onRouteCreated: (createdRoute) => route = createdRoute,
    builder: builder,
  );
  final completedRoute = route;
  if (completedRoute == null) return;
  await completedRoute.completed;
  container.invalidate(draftProvider);
}
