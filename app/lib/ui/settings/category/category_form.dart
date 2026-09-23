import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/delete_confirmation.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/common/pickers/symbol_picker.dart';
import 'package:spendwise/ui/settings/category/category_form_view_model.dart';

const _swatches = [
  defaultCategoryColor,
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF5AC8FA),
  Color(0xFFAF52DE),
  Color(0xFF8E8E93),
];

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

class CategoryForm extends ConsumerStatefulWidget {
  const CategoryForm({super.key, this.category, this.presetParentID});

  final TransactionCategory? category;
  final String? presetParentID;

  @override
  ConsumerState<CategoryForm> createState() => _CategoryFormState();
}

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

class _CategoryFormBody extends StatelessWidget {
  const _CategoryFormBody({
    required this.formState,
    required this.viewModel,
    required this.nameController,
  });

  final CategoryFormViewState formState;
  final CategoryFormViewModel viewModel;
  final TextEditingController nameController;

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
          TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: viewModel.setName,
          ),
          const SizedBox(height: 16),
          IgnorePointer(
            ignoring: formState.kindLocked,
            child: Opacity(
              opacity: formState.kindLocked ? 0.5 : 1,
              child: SegmentedButton<CategoryKind>(
                segments: const [
                  ButtonSegment(
                    value: CategoryKind.income,
                    label: Text('Income'),
                  ),
                  ButtonSegment(
                    value: CategoryKind.expense,
                    label: Text('Expense'),
                  ),
                ],
                selected: {formState.kind},
                onSelectionChanged: formState.kindLocked
                    ? null
                    : (selection) => viewModel.setKind(selection.first),
              ),
            ),
          ),
          if (formState.kindLocked)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Type is locked while transactions use this category.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Symbol'),
            leading: CategoryIcon(
              symbolName: formState.symbol,
              color: formState.color,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: viewModel.requestPickSymbol,
          ),
          const SizedBox(height: 16),
          Text('Color', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final swatch in _swatches)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => viewModel.setColor(swatch),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: swatch,
                      border: swatch == formState.color
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include in analysis'),
            value: formState.includeInAnalysis,
            onChanged: viewModel.setIncludeInAnalysis,
          ),
          if (formState.showParentPicker)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Parent'),
              trailing: Text(formState.parentLabel ?? 'None'),
              onTap: viewModel.requestPickParent,
            ),
          if (formState.isEditing) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: viewModel.requestDelete,
                child: const Text('Delete Category'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
