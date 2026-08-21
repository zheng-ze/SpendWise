# ui-foundation Specification

## Purpose
Defines the formatting, color, iconography and input rules shared by every screen, so that an amount
or a date looks the same wherever it appears and a future change to any of them is one edit.

## Requirements

### Requirement: Currency formatting

Money SHALL be formatted through a single shared function with grouping separators and two decimal
places. The single-currency assumption SHALL live in that one place, so that supporting more
currencies later is a localized change.

#### Scenario: Thousands are grouped

- **WHEN** a four-figure amount is formatted
- **THEN** it carries a grouping separator and exactly two decimal places

### Requirement: Amount sign and color

A transaction's magnitude SHALL always be displayed absolute, with its sign and color carrying the
meaning: income prefixed positive and colored as a gain, expense prefixed negative and colored as a
loss, and a transfer shown unsigned and neutral.

Net figures SHALL be colored by sign — gain when above zero, loss when below, neutral at exactly
zero.

Colors SHALL come from the theme so they hold in both light and dark. Text SHALL NOT be hardcoded
black.

#### Scenario: Expense display

- **WHEN** an expense is shown in a list
- **THEN** its magnitude is unsigned in the text, prefixed with a minus, and colored as a loss

#### Scenario: Zero net

- **WHEN** a day's net is exactly zero
- **THEN** it is colored neutrally rather than as a gain or a loss

### Requirement: Color parsing

A stored category color SHALL be parsed from a six-digit hex string with or without a leading hash.
Malformed input SHALL fall back to gray rather than failing.

Colors SHALL be written back as an uppercase six-digit hex string with a leading hash, components
clamped, and any alpha dropped.

#### Scenario: Malformed stored color

- **WHEN** a category's stored color cannot be parsed
- **THEN** it renders gray

### Requirement: Amount input sanitizing

Amount input SHALL be sanitized on every keystroke: everything except digits and a single decimal
point is stripped, fraction digits beyond two are **dropped rather than rounded**, and a single
leading minus is permitted only where negative values are allowed.

Only the balance field on the account and pocket edit forms SHALL allow negatives.

The sanitizer SHALL be a pure function so it can be tested without a widget.

#### Scenario: Extra fraction digits

- **WHEN** a third fraction digit is typed
- **THEN** it is dropped, and the first two digits are unchanged

#### Scenario: Minus where not allowed

- **WHEN** a minus is typed into a field that does not allow negatives
- **THEN** it is stripped

### Requirement: Date and percentage formatting

Day section headers SHALL show the day number with a secondary line carrying abbreviated weekday,
abbreviated month and year. Month and year selector labels, week ranges and plan next-occurrence
labels SHALL each have one shared format.

A week range SHALL be rendered from a half-open window by subtracting one day from the exclusive end
before formatting, so that the displayed end date is the last day actually included.

Percentages SHALL be shown with no fraction digits.

#### Scenario: Week range end is inclusive in display

- **WHEN** a half-open week window is rendered as a range
- **THEN** the displayed end is the last included day, not the exclusive boundary

### Requirement: Symbol mapping

Stored symbol names SHALL be mapped to icons at build time, covering both the fixed chrome set and
the full category catalog. An unrecognized name SHALL resolve to a fallback icon rather than failing,
since imported or synced data may carry names this build does not know.

Stored values SHALL remain the original symbol names, so data round-trips with the native app.

#### Scenario: Every catalog symbol resolves

- **WHEN** the category catalog is enumerated
- **THEN** every name maps to an icon

#### Scenario: Unknown symbol

- **WHEN** a category carries a symbol name this build does not know
- **THEN** it renders the fallback icon
