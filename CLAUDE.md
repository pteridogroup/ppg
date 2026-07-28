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

Handled by the `release-notes` skill
(`.claude/skills/release-notes/SKILL.md`, invocable as `/release-notes`):
diffs `data/ppg.csv` against the last version tag by `taxonID`, summarizes
additions/removals/taxonomic-status flips/other field changes, and
recommends which part of the version number to bump. Invoke it whenever
asked to summarize changes since the last release or draft release notes.
