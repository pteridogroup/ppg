---
name: release-notes
description: Prepare a PPG release description by comparing data/ppg.csv against the last released version, recommend which part of the version number to bump, and — after the user confirms — issue the release (tag + push + GitHub release). Use when the user asks to summarize what changed since the last release, draft release notes, figure out whether a version bump should be GENUS/SPECIES/MAJOR, or actually cut/publish a new release.
user-invocable: true
---

# release-notes — summarize `data/ppg.csv` changes for a PPG release

Compares the current `data/ppg.csv` against the last tagged version, produces a structured
summary of what changed, and recommends which part of the version number to bump. See
`CLAUDE.md` for the full `ppg.csv` schema and the versioning scheme
(`MAJOR.GENUS.SPECIES.DEV`); the essentials needed here are repeated below.

## Procedure

1. Find the last version tag: `git tag --sort=-creatordate | head -1`.
2. Extract both snapshots of the CSV for comparison:
   ```
   git show <last-tag>:data/ppg.csv > /tmp/ppg_old.csv
   cp data/ppg.csv /tmp/ppg_new.csv
   ```
   (or substitute a different ref for "new" if comparing two arbitrary points instead of
   tag-vs-working-tree).
3. Diff by `taxonID` (the stable WFO ID — not row order; rows get reordered/renumbered),
   using pandas or similar:
   - Added taxonIDs (new in the new file) — report scientificName, taxonRank,
     taxonomicStatus for each.
   - Removed taxonIDs (present in old, gone in new) — same, from the old file.
   - For taxonIDs in both: diff every column except `modified` (it updates on essentially
     every pipeline run regardless of other changes, so it's not evidence of a meaningful
     edit). Rows where only `modified` differs are pipeline noise — count them but don't
     report as changes.
   - For rows with real content changes, group by which column(s) changed and report
     counts, then call out the interesting ones by name:
     - `taxonomicStatus` transitions — tally as a small transition matrix (e.g.
       `accepted → synonym: 10`) and list the `accepted ↔ synonym` flips by name (these
       are the taxonomic decisions people most want to see in release notes —
       `unchecked → *` is routine curation and can just be a count).
     - `scientificName` changes — list all of them by taxonID; these are usually spelling
       corrections or hybrid-marker (`×`) fixes.
     - `parentNameUsageID` / `acceptedNameUsageID` changes — usually
       reclassification/re-parenting; a count is normally enough detail unless the user
       wants specifics.
4. Sanity-check the arithmetic (old row count + added − removed = new row count) before
   presenting the summary.
5. Present as a short structured summary (row count delta, additions with names/ranks,
   removals, taxonomic status flips by name, other field-change counts) — this is the
   basis for the release description.
6. Recommend which part of the version number should bump, based on the `taxonRank` of
   every added/removed/changed row (use the rank from the new row, or the old row if
   removed):
   - Any change at genus-level-or-above (genus, subgenus, family, order, class, etc.) →
     recommend a `GENUS` bump.
   - Changes confined entirely to species-level-or-below (species, subspecies, variety,
     form) → recommend a `SPECIES`-only bump.
   - `MAJOR` bumps are for wholesale/structural revisions (e.g. the eventual v2.0
     declaration) — flag if the change set looks unusually large or restructures a large
     fraction of the tree, but don't assume one from a normal diff.
   - This is a recommendation to surface alongside the summary, not an automatic decision
     — the actual bump (including whether to bump at all vs. leave it as a `DEV`
     increment) is made by the user.

## Issuing the release

Only do this after the user has seen the summary and explicitly confirms both the target
version number and that they want to proceed — this step pushes a tag and publishes a
public GitHub release, so never do it as a default continuation of the summary step.

7. Confirm with the user: the exact version string to tag (e.g. `v0.0.0.9009`), and the
   release notes text. Draft the notes in the same terse style as past releases (one line
   like "Development version", plus one short sentence on the headline change — e.g. "Adds
   Cryptocaulaceae" or "Removes nothogenera not currently recognized by PPG: ..." — not the
   full diff dump from the summary step), but let the user edit it before anything is
   published.
8. Once confirmed, from a clean working tree on `main` (verify with `git status`; if the
   version bump also involves non-`ppg.csv` changes like `README.md`, commit those first):
   ```
   git tag -a <version> -m "<release notes>"
   git push origin <version>
   gh release create <version> --title "PPG <version>" --notes "<release notes>"
   ```
9. Report the release URL back to the user.
