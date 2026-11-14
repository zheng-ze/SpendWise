import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/inputs/form_scaffold.dart';
import 'package:spendwise/ui/common/pickers/symbol_picker.dart';
import 'package:spendwise/ui/common/sheets/sheet_session.dart';
import 'package:spendwise/ui/settings/category/category_form_fields.dart';
import 'package:spendwise/ui/settings/category/category_form_view_model.dart';
import 'package:spendwise/ui/settings/category/confirm_move_category_to_bin.dart';
import 'package:spendwise/ui/settings/category/parent_picker.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';

// MARK: - Show

Future<void> showCategoryFormSheet({
  required BuildContext context,
  TransactionCategory? category,
  String? presetParentID,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
  void dispose() {
    _closePickers();
    _subscription?.close();
    _nameController.dispose();
    super.dispose();
  }

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
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
    if (!context.mounted || chosen == null) return;
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
    if (!context.mounted || chosen == null) return;
    _viewModel.applyPickedParent(chosen.parentID);
  }

  Future<void> _confirmDelete() async {
    final category = widget.category;
    if (category == null) return;
    final confirmed = await confirmMoveCategoryToBin(context, category.name);
    if (!context.mounted) return;
    await _viewModel.applyDeleteConfirmed(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(categoryFormViewModelProvider(_args));

    return asyncState.when(
      data: (formState) => _CategoryFormBody(
        formState: formState,
        viewModel: _viewModel,
        nameController: _nameController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
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

    return FormScaffold(
      title: formState.title,
      canSave: formState.canSave,
      onSave: viewModel.save,
      error: ErrorSection(subject: 'category', error: formState.error),
      child: Column(
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
      ),
    );
  }
}
