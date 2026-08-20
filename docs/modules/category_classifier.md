# Module spec — category classifier

**Scope:** an online Naive Bayes classifier that suggests a `TransactionCategory` for a new
`Entry` from its free-text `name`, learning per-device from the user's own accept, correct, and
ignore signals.

**Status:** design spec, pre-implementation. No Swift precursor exists — this module has no
source of truth to port from. Every rule below is the intended behavior for a first
implementation, to be verified by its own test suite once built.

**Relationship to the domain layer:** this module reads `LedgerState` (via `categories` and
`CategoryKind`) but never writes to it and never appears in a `LedgerChange`. It is a derived,
non-authoritative helper, not a ledger mutator. It has no invariants of its own to check against
`LedgerState.assertInvariants`, and a bug in it can never corrupt ledger state, at worst it
produces a bad suggestion the user is free to ignore.

---

## 1. Purpose

Reduce the friction of picking a category on every entry by suggesting one, then improving that
suggestion over time from the user's own corrections. The model trains only on this device, for
this user, starting from nothing, no bundled pretrained weights and no cross-user data.

## 2. Model

One multinomial Naive Bayes model per `CategoryKind` (`income`, `expense`), trained
independently, matching the existing split in `showCategoryPickerSheet`. A suggestion for an
income entry is never influenced by expense-category training data or vice versa.

### 2.1 Tokenization

Given an `Entry.name`:

1. Lowercase the string.
2. Split on any non-alphanumeric character.
3. Drop tokens shorter than 2 characters.
4. Emit every unigram from step 3, plus every adjacent bigram (token pairs in sequence).

Bigrams exist because a merchant name is often a fixed phrase: "kopi tiam" carries a signal that
"kopi" and "tiam" do not carry independently once mixed into a bag of unrelated words. Both
unigrams and bigrams feed the same per-category token counts below, there is no separate model
for each.

### 2.2 Per-category state

For each `TransactionCategory.id` within a `CategoryKind`, the model stores:

| Field | Type | Meaning |
|---|---|---|
| `tokenCounts` | `Map<String, int>` | count of each token seen in training examples labeled with this category |
| `totalTokens` | `int` | sum of `tokenCounts.values`, kept in sync on every update |
| `docCount` | `int` | number of training examples (entries) labeled with this category |

A category with no training examples has all three at zero. This is the cold-start state, and no
other code path treats it specially, see §4.

### 2.3 Online update — `observe(String name, String categoryId)`

1. Tokenize `name` per §2.1.
2. For each token, increment `tokenCounts[token]` by 1 (creating the entry if absent) and
   `totalTokens` by 1.
3. Increment `docCount` by 1.

This is the entire training step: no batch pass, no retraining of other categories, no gradient
computation. One call is O(number of tokens in the name) and touches only the target category's
state. A single user correction is reflected in the very next prediction.

### 2.4 Prediction — `predict(String name) -> List<(categoryId, double posterior)>`

For each active category of the matching `CategoryKind`:

1. Tokenize `name` per §2.1.
2. Compute the log-likelihood:

   ```
   logScore(category) = log(category.docCount / totalDocsAcrossCategories)
       + Σ over tokens: log((category.tokenCounts[token] + 1) / (category.totalTokens + vocabularySize))
   ```

   `vocabularySize` is the count of distinct tokens seen across all categories in this
   `CategoryKind`, and the `+ 1` in the numerator is Laplace (add-one) smoothing. Without it, a
   token never seen for a given category would zero out that category's entire score on the
   first occurrence of any new word, which is wrong: an unseen word is weak evidence against a
   category, not proof against it.
3. Convert the set of log-scores to normalized posteriors with a softmax, so the output is a
   probability distribution over categories that sums to 1, not just a ranking. The confidence
   gate in §4 depends on having a real number to threshold, not only an ordering.
4. Return the list sorted by posterior, descending.

If every category in the `CategoryKind` has `docCount == 0`, the log-likelihood term from step 2
degenerates to the same constant for every category (no token evidence exists anywhere), so the
softmax in step 3 produces a uniform distribution. This is what makes cold start fall out of the
formula rather than needing a branch, see §4.

## 3. Training signal sources

`predict` is called once per entry-name change while the user is composing an entry. `observe` is
called from three distinct points in the entry form flow, and they carry different signal
strength:

| Event | Signal | Trained? |
|---|---|---|
| Suggestion shown, user saves the entry without changing the category | strong positive, full weight | Yes |
| Suggestion shown, user opens the category picker and picks a different category before saving | explicit correction | Yes, on the picked category, not the suggested one |
| No suggestion was shown, or the user never interacted with it | no signal | No |

A correction is not weighted any higher than an acceptance in the scoring formula in §2.4, both
are one training example, but the distinction is recorded here because a correction is the
higher-value case to log for future model tuning: it is unambiguous evidence the model's decision
was wrong, whereas an acceptance is not proof the model's specific ranking was right, only that
the user did not object to it.

## 4. Confidence-gated suggestion

Given the ranked posteriors from §2.4, the entry form's suggestion UI branches three ways:

| Condition | Behavior |
|---|---|
| Top posterior ≥ 0.6 | Auto-fill the category field with the top suggestion. The user can still open the picker and override it, which is itself a training signal per §3. |
| Top posterior < 0.6 but the distribution is not uniform | Show the top 2–3 candidates as selectable chips instead of committing to one. A near-tie between two plausible categories is exactly the case where a single silent guess is more likely to be wrong than helpful. |
| All posteriors uniform or near-uniform (no category has meaningfully more evidence than any other) | Treat as no match. Prompt to create a new category instead of forcing a choice among existing ones that none of them fit. |

The 0.6 threshold is a starting point for the first implementation, not a value derived from
measurement, tune it against real usage once the feature has training data to test against.

### 4.1 Cold start is the third branch, not a special case

Before any `observe` call has been made for a `CategoryKind`, every category's posterior is equal
by construction (§2.4). That is indistinguishable, at the confidence-gate level, from the
low-confidence branch: no category is meaningfully favored, so the correct behavior, prompting to
create or manually pick a category, falls out of the same threshold check. A hand-written
keyword-to-category rule table (for example "starbucks" implying a food category) can be layered
in later purely as UX polish, to give the very first entry a plausible guess instead of an empty
state, but it is optional and never load-bearing: the classifier's correctness does not depend on
it existing.

## 5. Persistence

Each category's `tokenCounts`, `totalTokens`, and `docCount` are serialized and stored per-device
through the existing Drift-backed persistence layer, keyed by category id. `observe` updates the
stored blob incrementally, the model is never rebuilt from a full retraining pass over entry
history. This is intentionally the least interesting part of the design: any simple key-value
serialization that survives an app restart is sufficient, the online-update property in §2.3 is
what does the actual work.

## 6. Design rationale — why Naive Bayes

The requirement that matters most here is not raw classification accuracy, it is that a single
user correction be reflected immediately, on-device, without a training pass. Naive Bayes update
is O(tokens) and additive, so it satisfies that directly: no gradient descent, no epoch, no
held-out validation step between a correction and the next prediction. It is also fully
interpretable, the exact tokens and their per-category counts that produced a score can be shown
to a user or a developer, which a neural network's suggestion cannot offer without extra
machinery. The tradeoff is that Naive Bayes cannot learn representations the way an embedding or
transformer model can, word order beyond adjacent bigrams and semantic similarity between
different words are both invisible to it. That tradeoff is acceptable for this feature: entry
names are short, mostly merchant names or a few descriptive words, not prose that needs deeper
language understanding.

## 7. Non-goals

- Not a deep-learning model, no embeddings, no attention, no bundled pretrained weights of any
  kind.
- No cross-user or cross-device learning. Training data and model state are strictly per-device.
- Does not modify `LedgerState`, does not emit a `LedgerChange`, and is not covered by
  `LedgerState.assertInvariants`.
- Not a general text classifier, tokenization and feature choices in §2.1 are tuned for short
  transaction titles specifically.
