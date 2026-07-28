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

1. Find the last *released* version with `gh release list -R pteridogroup/ppg --limit 1`
   (the tag it reports, e.g. `v0.0.0.9008`) — don't use
   `git tag --sort=-creatordate | head -1` for this. Stray/typo tags can exist (e.g.
   `v0.0.0.90078` was a duplicate of `v0.0.0.9008` on the same commit — one extra digit,
   no real GitHub release behind it) and can outrank the real release tag under
   `--sort=-creatordate` when both share a commit/timestamp. `gh release list` reflects
   what was actually published, so it's the authoritative source. Only fall back to the
   git tag command if `gh` is unavailable, and in that case cross-check the result looks
   sane (matches a real release) before using it.
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
   - Only changes touching an *accepted* taxon at genus rank or above (genus, family,
     order, class, etc.) count toward a `GENUS` bump. Concretely, a row counts if it's at
     genus-or-above rank AND either:
     - it's a newly added row with `taxonomicStatus` = `accepted`,
     - an existing row's `taxonomicStatus` transitions into or out of `accepted`
       (`synonym/unchecked → accepted`, or `accepted → synonym/unchecked`), or
     - an existing row that is (and remains) `accepted` has its `scientificName`,
       `parentNameUsageID`, or `taxonRank` changed.
   - A genus-or-above row that is added, removed, or edited while its `taxonomicStatus`
     stays `synonym` (or `unchecked`) throughout does **not** count toward `GENUS` — it's
     routine synonymy bookkeeping (e.g. filling in a previously-missing obsolete name),
     not a change to the accepted classification. Fold it into the `SPECIES` bucket
     instead.
   - Changes confined to non-qualifying genus-or-above rows plus anything below genus rank
     — subgenus, section, species, subspecies, variety, form (subgenus is *below* genus in
     the hierarchy: class > order > family > genus > subgenus > species > subspecies >
     variety > form, despite the name sounding genus-adjacent) — → recommend a
     `SPECIES`-only bump.
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
   release notes text. Draft the notes as the structured summary from step 5 (row count
   delta, new taxa by name/rank, the transition tally, other field-change counts) formatted
   as markdown bullets — not the older terse one-liner style used by pre-9009 releases
   (e.g. "Development version / Adds Cryptocaulaceae"). Leave the sanity-check arithmetic
   out of the published notes — it's an internal QA step (step 4), not reader-facing
   content. Don't shout rank names in caps (`genus`/`species`, not `GENUS`/`SPECIES`) in
   prose meant for the release notes — the all-caps form is just this skill doc's shorthand
   for the version-number field. Let the user edit the notes before anything is published.
8. Once confirmed, from a clean working tree on `main` (verify with `git status`; if the
   version bump also involves non-`ppg.csv` changes like `README.md`, commit those first):
   ```
   git tag -a <version> -m "<release notes>"
   git push origin <version>
   gh release create <version> --title "PPG <version>" --notes "<release notes>"
   ```
9. Report the release URL back to the user.
