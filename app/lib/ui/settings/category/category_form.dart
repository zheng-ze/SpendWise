import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/inputs/form_section_card.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/symbol_picker.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/form_sheet_load_states.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/common/sheets/sheet_session.dart';
import 'package:spendwise/ui/settings/category/category_danger_button.dart';
import 'package:spendwise/ui/settings/category/category_form_fields.dart';
import 'package:spendwise/ui/settings/category/category_form_view_model.dart';
import 'package:spendwise/ui/settings/category/category_subcategories_section.dart';
import 'package:spendwise/ui/settings/category/confirm_move_category_to_bin.dart';
import 'package:spendwise/ui/settings/category/parent_picker.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';

// MARK: - Constants

const _loadingTitle = 'Category';
const _saveLabel = 'Save';
const _retryLabel = 'Try again';
const _loadErrorTitle = "Couldn't load this category";
const _saveErrorTitle = 'Could not save category';
const _addFooterLabel = 'Save category';
const _moveToBinLabel = 'Move to recycle bin';
const _footerWidth = double.infinity;

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
  bool _subcategorySheetOpen = false;

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
      categoryName: formState.name,
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

  void _openSubcategoryForm({
    TransactionCategory? subcategory,
    String? presetParentID,
  }) {
    if (_subcategorySheetOpen) return;
    _subcategorySheetOpen = true;
    Future<void> release(AppSheetRoute<void> route) async {
      await route.completed;
      _subcategorySheetOpen = false;
    }

    void track(AppSheetRoute<void> route) {
      _trackPicker(route);
      unawaited(release(route));
    }

    unawaited(
      showCategoryFormSheet(
        context: context,
        category: subcategory,
        presetParentID: presetParentID,
        onRouteCreated: track,
      ),
    );
  }

  void _openSubcategory(TransactionCategory subcategory) =>
      _openSubcategoryForm(subcategory: subcategory);

  void _addSubcategory() =>
      _openSubcategoryForm(presetParentID: widget.category?.id);

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
        onSubcategoryTap: _openSubcategory,
        onAddSubcategory: _addSubcategory,
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
    required this.onSubcategoryTap,
    required this.onAddSubcategory,
  });

  final CategoryFormViewState formState;
  final CategoryFormViewModel viewModel;
  final TextEditingController nameController;
  final ValueChanged<TransactionCategory> onSubcategoryTap;
  final VoidCallback onAddSubcategory;

  static const _fieldGap = 16.0;
  static const _editSectionGap = 12.0;

  @override
  Widget build(BuildContext context) {
    if (nameController.text != formState.name) {
      nameController.text = formState.name;
    }

    final save = TextButton(
      onPressed: formState.canSave ? viewModel.save : null,
      child: const Text(_saveLabel),
    );
    final gap = const SizedBox(height: _fieldGap);
    final editSectionGap = const SizedBox(height: _editSectionGap);
    final kind = CategoryKindSelector(
      kind: formState.kind,
      onKindSelected: viewModel.setKind,
    );
    final name = CategoryFormNameField(
      controller: nameController,
      onChanged: viewModel.setName,
      autofocus: !formState.isEditing,
    );
    final symbol = CategorySymbolTile(
      symbol: formState.symbol,
      color: formState.color,
      onTap: viewModel.requestPickSymbol,
    );
    final inside = CategoryParentTile(
      parentLabel: formState.parentLabel,
      onTap: formState.hasPresetParent ? null : viewModel.requestPickParent,
    );
    final showsInside = formState.hasPresetParent || formState.showParentPicker;
    final insideBeforeSymbol = formState.isSubcategoryForm;
    final collapsedMoreOptions = CategoryMoreOptions(
      includeInAnalysis: formState.includeInAnalysis,
      onIncludeInAnalysisChanged: viewModel.setIncludeInAnalysis,
      isSubcategory: formState.isSubcategoryForm,
    );
    final openMoreOptions = CategoryMoreOptionsSection(
      includeInAnalysis: formState.includeInAnalysis,
      onIncludeInAnalysisChanged: viewModel.setIncludeInAnalysis,
      kind: formState.kind,
      isSubcategory: formState.isSubcategoryForm,
      parentLabel: formState.parentLabel,
    );
    final fieldsCard = FormSectionCard(
      padding: FormSectionCard.fieldsPadding,
      children: [
        if (!formState.kindLocked) ...[kind, gap],
        name,
        gap,
        if (showsInside && insideBeforeSymbol) inside,
        symbol,
        if (showsInside && !insideBeforeSymbol) inside,
        if (!formState.isEditing) collapsedMoreOptions,
      ],
    );
    final subcategories = CategorySubcategoriesSection(
      subcategories: formState.activeSubcategories,
      onSubcategoryTap: onSubcategoryTap,
      onAddSubcategory: onAddSubcategory,
    );
    final moveToBin = CategoryDangerButton(
      label: _moveToBinLabel,
      onPressed: viewModel.requestDelete,
    );
    final body = formState.isEditing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fieldsCard,
              if (formState.showsSubcategories) ...[
                editSectionGap,
                subcategories,
              ],
              editSectionGap,
              openMoreOptions,
              editSectionGap,
              moveToBin,
            ],
          )
        : fieldsCard;
    final addFooter = PrimaryButton(
      label: _addFooterLabel,
      onPressed: formState.canSave ? viewModel.save : null,
    );
    final addFooterButton = formState.hasPresetParent ? null : addFooter;
    final footer = formState.isEditing || addFooterButton == null
        ? null
        : SizedBox(width: _footerWidth, child: addFooterButton);
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
      footer: footer,
      alert: alert,
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}
