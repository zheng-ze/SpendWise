# Sync enrollment: backend picker

Last reconciled: eea2aac

## Overview

`BackendPickerScreen` and its Riverpod `BackendPickerNotifier` own the initial
hosted-versus-custom sync-backend selection UI. `BackendPickerViewModel`
exposes backend selection, endpoint input, continuation, and one-shot steps.
The notifier depends only on `BackendSelectionWriter` and
`CustomEndpointValidation`; it does not construct or call an enrollment
service, resolver, coordinator, backend, or authenticator. Source:
`app/lib/ui/sync/enrollment/backend_picker/backend_picker_screen.dart` -
`BackendPickerScreen`; `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart`
- `BackendPickerViewModel`, `BackendPickerNotifier`.

## Key locations

- `app/lib/ui/sync/enrollment/backend_picker/backend_picker_screen.dart` -
  backend-choice screen and custom-endpoint field.
- `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart`
  - picker state, `BackendPickerViewModel`, notifier, and continuation steps.
- `app/lib/sync/backend_selection_writer.dart` - narrow durable-selection
  write seam implemented by `SyncMetadataStore`.

## Contracts and invariants

- `BackendPickerViewModel.continueWithSelection()` persists the hosted choice
  through `BackendSelectionWriter.setBackendSelection` before emitting
  `HostedReady`. For a valid custom endpoint, it persists the validated URI
  before emitting `CustomEndpointUnavailable`. Source:
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart`
  - `BackendPickerNotifier.continueWithSelection`, `_persistHosted`,
  `_persistCustom`.

## Gotchas

- No `FlowBase` wrapper, navigator route, or enrollment entry point constructs
  this screen yet. It is reachable only through its own tests until a flow
  owns its continuation steps. Source:
  `app/lib/ui/sync/enrollment/backend_picker/backend_picker_screen.dart` -
  `BackendPickerScreen`; `app/lib/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart`
  - `HostedReady`, `CustomEndpointUnavailable`.
