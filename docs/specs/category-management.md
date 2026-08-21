# category-management Specification

## Purpose
Defines how categories are seen and maintained: their ordering, what can be changed about one that is
already in use, and what deleting one costs.

## Requirements

### Requirement: Category list

Categories SHALL be listed in an income section and an expense section, each ordered as roots
alphabetically with each root followed by its own children alphabetically, and children indented.

A section with no categories SHALL say so.

A row SHALL show a marker when its category is excluded from analysis, so an exclusion is visible
without opening the form.

#### Scenario: Excluded category is marked

- **WHEN** a category is excluded from analysis
- **THEN** its row carries a marker

### Requirement: Creating categories

The list SHALL offer creation of a top-level category, defaulting to the expense kind.

A parent row SHALL additionally offer creation of a subcategory with that parent preset, inheriting
the parent's kind and color.

#### Scenario: Subcategory inherits from its parent

- **WHEN** a subcategory is created from a parent row
- **THEN** it starts with the parent's kind and color, and its parent preset

### Requirement: Kind locking

A category's kind SHALL be locked when its parent is preset, and when any entry references the
category being edited. The reason SHALL be stated to the user.

Changing the kind SHALL clear a parent selection that no longer matches.

#### Scenario: Kind locked by use

- **WHEN** a category referenced by entries is edited
- **THEN** its kind cannot be changed, and the form explains why

### Requirement: Category form

The form SHALL offer a name, a kind, a symbol, a color, analysis inclusion and a parent.

The parent choice SHALL offer none plus root categories of the same kind, excluding the category
itself, and SHALL be hidden when a parent is preset or nothing is eligible.

Saving SHALL require a non-blank name. Failures SHALL surface in the form.

A new category SHALL default to the tag symbol, a default color or its parent's, and analysis
included.

#### Scenario: A category cannot parent itself

- **WHEN** an existing category's parent is chosen
- **THEN** it is not offered as its own parent

### Requirement: Symbol picking

The symbol picker SHALL present the catalog as a searchable sectioned grid, rendered in the form's
current color, marking the current selection.

Search SHALL filter by case-insensitive substring on the symbol name, dropping sections with no
matches. Choosing a symbol SHALL record it and return.

#### Scenario: Search narrows the grid

- **WHEN** a search term matches symbols in only some sections
- **THEN** the sections without matches are not shown

### Requirement: Deleting a category

Deletion from the list SHALL ask for confirmation, stating how many entries will become
uncategorized when any reference it, and otherwise that the category will simply be removed.

Deletion SHALL archive to the recycle bin rather than destroying the category.

Deleting from within the form SHALL archive and dismiss without a confirmation, since the list path
is the confirmed one.

#### Scenario: Referenced category

- **WHEN** a category with referencing entries is deleted from the list
- **THEN** the confirmation states how many entries will become uncategorized
