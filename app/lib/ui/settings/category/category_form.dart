import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/symbol_picker.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/form_sheet_load_states.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/common/sheets/sheet_session.dart';
import 'package:spendwise/ui/settings/category/category_form_fields.dart';
import 'package:spendwise/ui/settings/category/category_form_view_model.dart';
import 'package:spendwise/ui/settings/category/confirm_move_category_to_bin.dart';
import 'package:spendwise/ui/settings/category/parent_picker.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';

// MARK: - Constants

const _loadingTitle = 'Category';
const _saveLabel = 'Save';
const _retryLabel = 'Try again';
const _loadErrorTitle = "Couldn't load this category";
const _saveErrorTitle = 'Could not save category';
const _footerWidth = double.infinity;
const _bodyPadding = EdgeInsets.fromLTRB(16, 8, 16, 16);

// MARK: - Show

Future<void> showCategoryFormSheet({
  required BuildContext context,
  TransactionCategory? category,
  String? presetParentID,
  void Function(AppSheetRoute<void>)? onRouteCreated,
}) {
  return showAppSheet<void>(
    context,
    presentation: shellSheetPresentation(context),
    presentationResolver: shellSheetPresentation,
    onRouteCreated: onRouteCreated,
    builder: (_) =>
        CategoryForm(category: category, presetParentID: presetParentID),
  );
}

// MARK: - Form

class CategoryForm extends ConsumerStatefulWidget {
  const CategoryForm({super.key, this.category, this.presetParentID});

  final TransactionCategory? category;
  final String? presetParentID;

  @override
  ConsumerState<CategoryForm> createState() => _CategoryFormState();
}

// MARK: - Form State

class _CategoryFormState extends ConsumerState<CategoryForm> {
  late final TextEditingController _nameController = TextEditingController();

  ProviderSubscription<AsyncValue<CategoryFormViewState>>? _subscription;

  ModalRoute<Object?>? _route;
  final List<ModalRoute<dynamic>> _pickerRoutes = [];

  CategoryFormArgs get _args => CategoryFormArgs(
    category: widget.category,
    presetParentID: widget.presetParentID,
  );

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      categoryFormViewModelProvider(_args),
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _closePickers();
    _subscription?.close();
    _nameController.dispose();
    super.dispose();
  }

  bool get _formIsActive => mounted && (_route?.isActive ?? false);

  void _trackPicker(ModalRoute<dynamic> route) => _pickerRoutes.add(route);

  void _closePickers() {
    final routes = List.of(_pickerRoutes);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        dismissSheetRoute(route);
      }
    });
  }

  CategoryFormViewModel get _viewModel =>
      ref.read(categoryFormViewModelProvider(_args).notifier);

  void _handleStep(CategoryFormStep? step) {
    if (step == null) return;
    switch (step) {
      case PickParentRequested():
        _pickParent();
      case PickSymbolRequested():
        _pickSymbol();
      case DeleteConfirmationRequested():
        _confirmDelete();
      case CategoryFormSaved():
        dismissSheetRoute(_route);
    }
    _viewModel.clearStep();
  }

  Future<void> _pickSymbol() async {
    final formState = ref.read(categoryFormViewModelProvider(_args)).value;
    if (formState == null) return;
    final chosen = await showSymbolPickerSheet(
      context: context,
      presentation: shellSheetPresentation,
      symbol: formState.symbol,
      color: formState.color,
      swatches: categorySwatches,
      onRouteCreated: _trackPicker,
    );
    if (!_formIsActive || chosen == null) return;
    _viewModel.applyPickedSymbolAndColor(chosen.symbol, chosen.color);
  }

  Future<void> _pickParent() async {
    final formState = ref.read(categoryFormViewModelProvider(_args)).value;
    if (formState == null) return;
    final chosen = await showParentPickerSheet(
      context: context,
      presentation: shellSheetPresentation,
      parents: formState.eligibleParentsList,
      currentParentID: formState.parentID,
      onRouteCreated: _trackPicker,
    );
    if (!_formIsActive || chosen == null) return;
    _viewModel.applyPickedParent(chosen.parentID);
  }

  Future<void> _confirmDelete() async {
    final category = widget.category;
    if (category == null) return;
    final confirmed = await confirmMoveCategoryToBin(context, category.name);
    if (!_formIsActive) return;
    await _viewModel.applyDeleteConfirmed(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(categoryFormViewModelProvider(_args));

    final formState = asyncState.value;
    if (formState != null) {
      return _CategoryFormBody(
        formState: formState,
        viewModel: _viewModel,
        nameController: _nameController,
      );
    }
    final error = asyncState.error;
    if (error == null) return const FormSheetLoading(title: _loadingTitle);
    final retry = SizedBox(
      width: _footerWidth,
      child: PrimaryButton(
        label: _retryLabel,
        onPressed: () => ref.invalidate(categoryFormViewModelProvider(_args)),
      ),
    );
    return FormSheetLoadError(
      title: _loadingTitle,
      message: _loadErrorTitle,
      error: error,
      footer: retry,
    );
  }
}

// MARK: - Body

class _CategoryFormBody extends StatelessWidget {
  const _CategoryFormBody({
    required this.formState,
    required this.viewModel,
    required this.nameController,
  });

  final CategoryFormViewState formState;
  final CategoryFormViewModel viewModel;
  final TextEditingController nameController;

  static const _fieldGap = 16.0;
  static const _deleteSectionGap = 24.0;

  @override
  Widget build(BuildContext context) {
    if (nameController.text != formState.name) {
      nameController.text = formState.name;
    }

    final save = TextButton(
      onPressed: formState.canSave ? viewModel.save : null,
      child: const Text(_saveLabel),
    );
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryFormNameField(
          controller: nameController,
          onChanged: viewModel.setName,
        ),
        const SizedBox(height: _fieldGap),
        CategoryKindSelector(
          kind: formState.kind,
          locked: formState.kindLocked,
          onKindSelected: viewModel.setKind,
        ),
        const SizedBox(height: _fieldGap),
        CategorySymbolTile(
          symbol: formState.symbol,
          color: formState.color,
          onTap: viewModel.requestPickSymbol,
        ),
        const SizedBox(height: _fieldGap),
        CategoryAnalysisSwitch(
          value: formState.includeInAnalysis,
          onChanged: viewModel.setIncludeInAnalysis,
        ),
        if (formState.showParentPicker)
          CategoryParentTile(
            parentLabel: formState.parentLabel,
            onTap: viewModel.requestPickParent,
          ),
        if (formState.isEditing) ...[
          const SizedBox(height: _deleteSectionGap),
          CategoryDeleteButton(onPressed: viewModel.requestDelete),
        ],
      ],
    );
    final body = Material(
      type: MaterialType.transparency,
      child: Padding(padding: _bodyPadding, child: fields),
    );
    final saveError = formState.error;
    final alert = saveError == null
        ? null
        : SheetAlertData(
            message:
                '$_saveErrorTitle\n${friendlyLedgerErrorMessage(saveError)}',
            severity: SheetAlertSeverity.error,
          );

    return AppSheet(
      header: AppPickerHeader(title: formState.title, trailing: save),
      body: body,
      alert: alert,
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}
