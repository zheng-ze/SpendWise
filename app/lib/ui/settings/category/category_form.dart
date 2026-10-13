import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/delete_confirmation.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/inputs/form_scaffold.dart';
import 'package:spendwise/ui/common/pickers/symbol_picker.dart';
import 'package:spendwise/ui/settings/category/category_form_fields.dart';
import 'package:spendwise/ui/settings/category/category_form_view_model.dart';

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
    _subscription?.close();
    _nameController.dispose();
    super.dispose();
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
      selected: formState.symbol,
      color: formState.color,
    );
    if (!context.mounted) return;
    if (chosen == null) return;
    _viewModel.applyPickedSymbol(chosen);
  }

  Future<void> _pickParent() async {
    final formState = ref.read(categoryFormViewModelProvider(_args)).value;
    if (formState == null) return;
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('None'),
              onTap: () => Navigator.of(context).pop(),
            ),
            for (final option in formState.eligibleParentsList)
              ListTile(
                title: Text(option.name),
                onTap: () => Navigator.of(context).pop(option.id),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    _viewModel.applyPickedParent(chosen);
  }

  Future<void> _confirmDelete() async {
    final category = widget.category;
    if (category == null) return;
    final confirmed = await showDeleteConfirmation(
      context,
      itemName: category.name,
    );
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
          CategoryColorPicker(
            selected: formState.color,
            onColorSelected: viewModel.setColor,
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
