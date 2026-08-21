# category-detail Specification

## Purpose
Defines the drill-down into one category: how a scope narrows what is counted, how the subcategory
breakdown is built, what the trend shows, and which entries are listed.

## Requirements

### Requirement: Independent date, inherited range

The detail screen SHALL keep its own selected date, seeded from the screen that opened it, so that
moving through periods here does not change the parent screen.

It SHALL inherit the range — month or year — fixed, and SHALL NOT offer a range control.

#### Scenario: Date changes stay local

- **WHEN** the user moves to a previous period in the detail screen and goes back
- **THEN** the parent screen's period is unchanged

### Requirement: Scope selection

The screen SHALL support three scopes: the whole category including its children, a single
subcategory, or the parent category directly.

Changing scope SHALL rescope everything below it — the total, the trend and the entry list.

The scope SHALL determine which categories match: the whole category matches itself and its children,
a subcategory matches only itself, and the direct scope matches only entries carrying the parent's
own category.

The bucket with no category SHALL be modelled explicitly rather than as an absent value, so that
"uncategorized" and "no constraint" cannot be confused.

#### Scenario: Direct scope excludes children

- **WHEN** the direct scope is selected
- **THEN** only entries logged on the parent category itself are counted

### Requirement: Subcategory table

When a category has children, the screen SHALL show a table beginning with a row for the whole
category, at full proportion and carrying the combined total.

Below it, the children and a direct row SHALL be ordered together by amount descending, so the direct
row ranks by its own amount rather than being pinned in place.

The direct row SHALL exist only when the category's own total exceeds the sum of its children — that
is, only when entries were logged on the parent itself.

Fractions in this table SHALL be proportions of the category's total, not of the whole period.

#### Scenario: No direct spending

- **WHEN** every entry sits on a child category
- **THEN** no direct row is shown

#### Scenario: Direct row ranks by amount

- **WHEN** direct spending exceeds one child's spending
- **THEN** the direct row appears above that child

### Requirement: Trend

The screen SHALL show a trend of the current scope's totals per month: in month range, the six months
ending with the selected month; in year range, all twelve months of the selected year. Months SHALL
be ordered oldest first.

Selecting a point SHALL show that month and its amount in place of the range hint.

#### Scenario: Trend crosses a year boundary

- **WHEN** the selected month is January in month range
- **THEN** the trend covers the preceding months of the previous year

### Requirement: Scoped entry list

The screen SHALL list entries grouped into day sections as the transactions screen does, filtered to
the categories the current scope matches, with sections that become empty dropped.

Rows SHALL offer the same interactions as the transactions list: tapping opens the entry, and swiping
offers a confirmed delete.

#### Scenario: Rescoping filters the list

- **WHEN** the scope narrows to one subcategory
- **THEN** only that subcategory's entries remain listed

### Requirement: Recompute only on change

The screen SHALL recompute its filtered scan only when the analysis cache reports new items, applying
the period filter per call rather than rescanning.

#### Scenario: Period change without new data

- **WHEN** the user changes period while the cache is unchanged
- **THEN** the underlying scan is reused rather than recomputed
