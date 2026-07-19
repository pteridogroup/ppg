# CLAUDE.md

## Repo purpose

This repo maintains the Pteridophyte Phylogeny Group (PPG) taxonomic
database for ferns and lycophytes (future "PPG II"), building on
[PPG I (2016)](https://doi.org/10.1111/jse.12229). Background/rationale for
the project is described in
[ppg2_ms.Qmd](https://github.com/pteridogroup/ppg2-ms/blob/main/ppg2_ms.Qmd).

Key files:
- [data/ppg.csv](data/ppg.csv) — the database, in Darwin Core (DwC) format.
  One row per taxon name.
- [data/ppg.md](data/ppg.md) — human-readable rendering of the same data.
- `_targets.R` / `_targets/` — the `targets` pipeline that (re)builds the
  data from raw sources.
- `.github/workflows/update-ppg.yml` — runs the pipeline daily and commits
  any changed data files to `main` as `Auto-update: <timestamp>` commits.
  Most commits on `main` are these automated commits, not manual edits.

## `data/ppg.csv` schema

One row per taxon. Key columns (DwC terms):
- `taxonID` — stable unique ID (WFO ID, e.g. `wfo-0001116439`). Use this as
  the join key when diffing two versions of the file, not row position.
- `scientificName` — the name string, including hybrid marker (`×`) and
  infraspecific rank abbreviation (var., subsp., f.) where applicable.
- `scientificNameAuthorship`, `namePublishedIn` — nomenclatural citation.
- `taxonRank` — e.g. class, order, family, genus, subgenus, species,
  variety, form.
- `parentNameUsageID` — taxonID of the parent in the classification tree.
- `acceptedNameUsageID` — taxonID of the accepted name, when this row is a
  synonym; `NA` for accepted names.
- `taxonomicStatus` — one of `accepted`, `synonym`, `unchecked` (not yet
  reviewed by a PPG curator).
- `nomenclaturalStatus` — e.g. `valid`, `conserved`.
- `created`, `modified` — dates. `modified` updates on essentially every
  pipeline run (even for rows with no other change), so it is not by itself
  evidence of a meaningful edit — ignore it when diffing unless it's the
  only thing that changed for a row worth flagging as "touched but
  unchanged."

## Versioning

- `ppg2_ms.Qmd` gives a simplified, general-audience description of the
  scheme as three digits (species/genus/major). The actual planned scheme,
  in effect from v2.0 onward, is four digits:
  `MAJOR.GENUS.SPECIES.DEV`. `MAJOR`/`GENUS`/`SPECIES` bump the same way as
  the simplified description; `SPECIES` bumps if a release includes *at
  least one* species-level-or-below change. `DEV` is reserved for
  in-between developer/dev-version changes (not yet a full release).
- Current tags (pre-v2.0) are `v0.0.0.9NNN` (R-package dev-version style,
  e.g. `v0.0.0.90078`) — all dev-version bumps under the not-yet-released
  `0.0.0` baseline. Per `README.md`, the version stays below `2` until the
  data are declared the official PPG II system.
- A version bump is a manual decision (not every automated data commit gets
  tagged) — find the last released version with
  `git tag --sort=-creatordate | head -1`, not just the latest commit.

## Task: prepare a release description (summarize changes since last version)

When asked to summarize what changed in `data/ppg.csv` since the last
release, to draft release notes for a version bump:

1. Find the last version tag: `git tag --sort=-creatordate | head -1`.
2. Extract both snapshots of the CSV for comparison:
   ```
   git show <last-tag>:data/ppg.csv > /tmp/ppg_old.csv
   cp data/ppg.csv /tmp/ppg_new.csv
   ```
   (or substitute a different ref for "new" if comparing two arbitrary
   points instead of tag-vs-working-tree).
3. Diff by `taxonID` (not row order — rows get reordered/renumbered), using
   pandas or similar:
   - Added taxonIDs (new in the new file) — report scientificName,
     taxonRank, taxonomicStatus for each.
   - Removed taxonIDs (present in old, gone in new) — same, from the old
     file.
   - For taxonIDs in both: diff every column except `modified`. Rows where
     only `modified` differs are pipeline noise — count them but don't
     report as changes.
   - For rows with real content changes, group by which column(s) changed
     and report counts, then call out the interesting ones by name:
     - `taxonomicStatus` transitions — tally as a small transition matrix
       (e.g. `accepted → synonym: 10`) and list the `accepted ↔ synonym`
       flips by name (these are the taxonomic decisions people most want
       to see in release notes — `unchecked → *` is routine curation and
       can just be a count).
     - `scientificName` changes — list all of them by taxonID; these are
       usually spelling corrections or hybrid-marker (`×`) fixes.
     - `parentNameUsageID` / `acceptedNameUsageID` changes — these are
       usually reclassification/re-parenting; a count is normally enough
       detail unless the user wants specifics.
4. Sanity-check the arithmetic (old row count + added − removed = new row
   count) before presenting the summary.
5. Present as a short structured summary (row count delta, additions with
   names/ranks, removals, taxonomic status flips by name, other field-change
   counts) — this is the basis for the release description.
6. Recommend which part of the version number should bump, based on the
   `taxonRank` of every added/removed/changed row (use the rank from the
   new row, or the old row if removed):
   - Any change at genus-level-or-above (genus, subgenus, family, order,
     class, etc.) → recommend a `GENUS` bump.
   - Changes confined entirely to species-level-or-below (species,
     subspecies, variety, form) → recommend a `SPECIES`-only bump.
   - `MAJOR` bumps are for wholesale/structural revisions (e.g. the
     eventual v2.0 declaration) — flag if the change set looks unusually
     large or restructures a large fraction of the tree, but don't assume
     one from a normal diff.
   - This is a recommendation to surface alongside the summary, not an
     automatic decision — the actual bump (including whether to bump at
     all vs. leave it as a `DEV` increment) is made by the user (see
     "Versioning" above).
