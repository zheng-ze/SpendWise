# Money Manager Import

Last reconciled: 2026-11-28

## Feature overview

Settings has an "Import from Money Manager" row in its Data section. The user picks an `.xlsx`
export, confirms a destructive replacement, and the whole ledger (accounts, pockets, entries,
categories, budgets, plans and the recycle bin) is replaced by the imported ledger in one commit.
Any invalid row or unreadable file lists its errors and leaves the ledger unchanged, in memory and
on disk. Display preferences are kept. A successful import shows no success message. The Settings
side (row, ViewModel state, Flow steps) is also described in `settings-ui.md`.

## Key files

- `app/lib/import/import_file_picker_service.dart` - the picker seam: abstract `ImportFilePicker`
  (`Future<Uint8List?> pick()`), the default `FileSelectorImportFilePicker`, the
  `excelWorkbookTypeGroup`, and `importFilePickerProvider`, which tests override with a fake.
- `app/lib/import/xlsx/xlsx_reader.dart`, `xlsx_sheet.dart` - `XlsxReader.read` returns an
  `XlsxSheet` (rows of raw cell text plus `date1904`) or throws `XlsxReadFailure`.
- `app/lib/import/money_manager/money_manager_records.dart` - `parseMoneyManagerSheet`,
  `MoneyManagerRow`, and the sealed `MoneyManagerImportError` hierarchy.
- `app/lib/import/money_manager/money_manager_ledger_builder.dart` - `buildMoneyManagerLedger`.
- `app/lib/import/money_manager/money_manager_importer.dart` - `MoneyManagerImporter.run`, the
  sealed `ImportOutcome`, `ImportBuildRunner`, `isolateImportBuildRunner` and
  `syncImportBuildRunner`.
- `app/lib/boot/providers.dart` - `moneyManagerImporterProvider`, built from `ledgerProvider` and
  `persistenceProcessorProvider`, and null until both exist.
- `app/lib/ui/settings/settings_root_view_model.dart`, `settings_flow.dart`,
  `settings_root_screen.dart`, `import_errors_sheet.dart`, `import_error_text.dart` - the UI side.
- `packages/domain/lib/src/ledger_state/mutators/ledger_state_replace.dart` and
  `app/lib/ledger/ledger.dart` - `LedgerState.replaceContents` and `Ledger.replaceContents`.
- `app/macos/Runner/DebugProfile.entitlements`, `Release.entitlements` - the file-read entitlement.
- `app/test/support/xlsx_fixture.dart` - builds synthetic `.xlsx` bytes for the tests; the real
  export is never committed.

## Module interactions

1. **Row.** `_ImportRow` in `settings_root_screen.dart` calls `requestImport` on
   `SettingsRootNotifier`. The row is disabled unless `importStatus` is `idle` and shows an
   `InlineSpinner` while `running`.
2. **Pick.** `requestImport` is ignored unless the status is `idle`, then sets `picking` and emits
   `ImportFileRequested`. `SettingsFlow._pickImportFile` reads the notifier and
   `importFilePickerProvider` before awaiting, calls `pick()`, and reports the raw result through
   `applyPickedFile(bytes:)` or `applyPickedFile(pickerError:)`.
   `FileSelectorImportFilePicker` calls `openFile` with `excelWorkbookTypeGroup` (extension `xlsx`,
   the OOXML spreadsheet MIME type and UTI) and reads the file bytes.
3. **Confirm.** Picked bytes are kept in the ViewModel, the status becomes `confirming`, and
   `ImportConfirmationRequested` makes `SettingsFlow._confirmImport` call
   `showDestructiveConfirmation` (title "Replace all data?", confirm label "Replace"). The Flow
   passes the result to `applyImportConfirmed`. Cancel or dismissal drops the bytes and returns to
   `idle`.
4. **Run.** `applyImportConfirmed(true)` takes `ref.keepAlive()`, sets `running`, awaits
   `MoneyManagerImporter.run` through `_runImport` (a throw becomes `ImportFailedUnexpectedly`),
   returns to `idle`, and maps the outcome with `importErrorMessages`
   (`import_error_text.dart`). An empty list closes the keep-alive link at once. A non-empty list
   is stored in `importErrors`, emits `ImportErrorsRequested`, and keeps the link open until
   `dismissImportErrors`.
5. **Errors sheet.** `SettingsFlow._showImportErrors` opens `showImportErrorsSheet` (an `AppSheet`
   titled "Couldn't import" with a list of messages and no Cancel) and calls
   `dismissImportErrors` when it closes.
6. **Held step.** `SettingsFlow.initState` schedules one post-frame callback, `_handleHeldStep`,
   that reads the current `step` of `settingsRootViewModelProvider` and passes it through
   `handleStep`. A new Flow has no navigator context during `initState`, so without this a step
   held by the kept-alive notifier would be skipped. `handleStep` clears the step first, so it
   shows once.

## Import pipeline

`MoneyManagerImporter.run` returns a sealed `ImportOutcome`: `ImportSucceeded`,
`ImportRejected(errors)`, `ImportSaveFailed`, or `ImportFailedUnexpectedly`.

1. **Read and build off the main isolate.** The injected `ImportBuildRunner` runs
   `readAndBuildMoneyManagerLedger`. The default `isolateImportBuildRunner` uses `Isolate.run` and
   must not capture the calling instance. Tests pass `syncImportBuildRunner`.
2. **Read.** `XlsxReader` opens the zip with `archive` and the XML with `xml`. It finds the sheet by
   resolving the first `<sheet>` through `xl/_rels/workbook.xml.rels` (a relative or `/`-absolute
   target), keeps every cell as raw text (shared strings, `inlineStr`, `str` and numbers), and places
   cells by the column letters of their `r` reference so a gap becomes an empty cell. Every
   malformed-input path ends in `XlsxReadFailure`, including a non-integer or out-of-range
   shared-string index and any other thrown object. `readAndBuildMoneyManagerLedger` turns it into
   `ImportBuildRejected([UnreadableFile()])`.
3. **Parse.** `parseMoneyManagerSheet` matches headers by exact trimmed name, first occurrence.
   Required: Date, Account, Category, Subcategory, Note, Income/Expense, Description, Amount,
   Currency. A missing header gives `MissingColumns`, and a sheet with only a header gives `NoRows`.
   Every row is checked and all row errors are collected before any build (`InvalidDate`,
   `MissingAccount`, `MissingCategory`, `MissingDestination`, `UnsupportedType`, `InvalidAmount`,
   `UnsupportedCurrency`), each carrying the 1-based sheet row. The type must be `Expense`,
   `Income` or `Transfer-Out`, and the currency must be `SGD`.
4. **Amount.** The Amount cell is parsed as text with `Decimal.tryParse`. It must be greater than
   zero and have at most two decimal places (`_maxAmountScale`).
5. **Date.** The serial is parsed as a `Decimal`, floored to the whole day `n` (at least 1), and
   mapped to `DateTime.utc(1899, 12, 30 + n)`, or `DateTime.utc(1904, 1, 1 + n)` when `date1904` is
   set. `Entry` normalizes it with `startOfDayUtc`.
6. **Build.** `buildMoneyManagerLedger` fills a fresh `LedgerState` through the real mutators
   (`addAccount`, `addCategory`, `addEntry`), with ids from an injected `String Function() newID`
   that defaults to the domain `newID`.
   - Accounts are created once per exact trimmed name, in first-seen order, as `AccountType.other`
     with default flags. No pockets are created.
   - Categories are keyed by (kind, parent, name) and created once with symbol `tag`, colour
     `#007AFF` and `includeInAnalysis: true`. A non-empty Subcategory creates a child, and the entry
     books to the child.
   - An Expense row becomes a negative entry from its account with no destination, an Income row a
     positive entry, and a Transfer-Out row a positive entry whose destination is the account named
     by the Category column, with no category.
   - The entry name is the Note, else the Subcategory, else the Category, or `Transfer to <name>`
     for a transfer. The Description becomes the entry note.
7. **Replace.** Back on the main isolate, `run` takes a snapshot of the current state (a new
   `LedgerState` over the same six maps) and calls `Ledger.replaceContents(imported)` with no await
   between them. Any throw before this point, including from the builder, the runner or an
   invariant check inside `replaceContents`, returns `ImportFailedUnexpectedly` with the ledger
   revision unchanged.
8. **Save and roll back.** `_save` awaits `flush`, which is `PersistenceProcessor.flush` and so
   `store.flushNow`. If the flush throws, `run` calls `Ledger.replaceContents(snapshot)` and returns
   `ImportSaveFailed`. Memory is restored at once, and the persistence rollback batch brings the
   disk back to the original (see `persistence.md`, "Replace-all batches and rollback").

## Domain and ledger replacement

`LedgerState.replaceContents(replacement)` (`ledger_state_replace.dart`) validates first with
`replacement.assertInvariants()`, so an invalid replacement throws and leaves the receiver
unchanged. It then builds the changes: deletes for every current row (budgets, plans, active and
binned entries, categories, money sources), followed by upserts for every replacement row (accounts,
pockets, parent categories before children, active entries, binned entries, plans, budgets). It
applies them with `apply`, resets `_lifecycleAtLastCheck` to null so an id shared with an old row
does not trip the one-way lifecycle check, and returns the changes. Replacing an empty ledger with
an empty one returns `[]`.

`Ledger.replaceContents` wraps it in `_mutate`: one batch, one revision bump, one bus publication
and one listener notification. An empty change list publishes nothing and keeps the revision.

## macOS entitlement

The macOS app is sandboxed, so `DebugProfile.entitlements` and `Release.entitlements` both carry
`com.apple.security.files.user-selected.read-only`. Without it the picker returns a file the app
cannot read. iOS and Android need no entries. `file_selector` is the pubspec dependency; `archive`
and `xml` are the pure-Dart parsing dependencies (`app/pubspec.yaml`).

## Gotchas and invariants

- **Display preferences are kept.** The import touches only the ledger and `store_meta` is not
  written, so `has_seeded` stays set and a wiped ledger is not re-seeded.
- **No success message.** `importErrorMessages` returns an empty list for `ImportSucceeded`, so
  Settings shows nothing on success; the new data appears in the other destinations.
- **Accounts are the union** of the Account column and the Category values of Transfer-Out rows
  (`_LedgerBuilder._accountID` is used for both), so a destination-only account is created too.
- **Other once per kind.** Categories are keyed by kind, so "Other" exists once as an expense root
  and once as an income root, never twice for one kind.
- **Amount column as text.** The reader never converts cells to numbers, and `Decimal.tryParse`
  reads the text, so no `double` is involved. An Expense text such as `2.0` is stored negated.
- **The dimension reference is ignored.** `XlsxReader` reads the `<row>` elements and never
  `<dimension ref>`, because the real export declares `A1` for a sheet of more than a thousand rows.
- **A duplicate header resolves to the first column.** `_columnIndexes` uses `putIfAbsent`, so the
  repeated "Account" header resolves to the first occurrence.
- **Errors survive leaving Settings.** The keep-alive link is held until `dismissImportErrors`, and
  `applyPickedFile` returns early when `ref.mounted` is false.
- **Edits made during the save-retry window are discarded** if the save then fails, because the
  rollback restores the pre-import snapshot. The shell's save-failure banner can appear alongside
  the "Couldn't save the import" message until the timed retry commits the net result.
- **Debug builds are slower.** With asserts enabled, every mutator runs the full invariant sweep
  after it applies, and release builds skip it. In a measurement of `buildMoneyManagerLedger` on
  1057 synthetic rows (19 accounts, 22 categories), a run with asserts enabled took 184 ms and a
  run without asserts took 17 ms. At export size this cost is not a practical problem, and the
  build runs inside the isolate, off the main isolate.

## Requirements

- A valid file replaces the whole ledger in one batch and one revision bump; an invalid or
  unreadable file changes nothing. (`money_manager_importer.dart`, `ledger_state_replace.dart`)
- Row validation collects every error with its sheet row before building.
  (`money_manager_records.dart`: `parseMoneyManagerSheet`)
- A failed save restores the pre-import ledger in memory and on disk, and reports
  `ImportSaveFailed`. (`MoneyManagerImporter._save`; `app/test/persistence/drift_ledger_store_test.dart`
  group `replace batch`)
- Only one import runs at a time: a request while the status is not `idle` is ignored.
  (`SettingsRootNotifier.requestImport`)
- Imported money is `Decimal`, ids are lowercase uuids, and dates are UTC midnight of the exported
  calendar day. (`money_manager_records.dart`, `money_manager_ledger_builder.dart`)
