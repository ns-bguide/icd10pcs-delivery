# Merge analysis — David's PR #1 (surgical) × Bruno's medical-side work

**Date:** 2026-06-12 · **PR:** ns-bguide/icd10pcs-delivery#1 (`ns-dalvarezpons`, ENG-837988)
**Deliverable under merge:** `grammar/ns_ecr_industries-healthcare-icd10pcs_procedures.xml`

## The situation

Both work-streams edited the **same delivery artifact** (the generated grammar XML)
from the **same common ancestor** (delivery `61d114f initial commit`), independently:

| | Lines | Entities added | Patterns Δ | Entries Δ |
|---|---:|---|---:|---|
| BASE (initial commit) | 19,098 | — | 259 | 17,697 |
| DAVID (PR #1) | 19,285 | +7 (surgical_actions / common_actions ×4 sections) | +85 / −29 | +90 / −8 |
| MINE (current) | 19,149 | +1 (ops_lat) | +13 / −1 | +15 / −197 |

The XML is produced by a generator (`icd10pcs-grammar-automation` repo) on my side,
but **the deliverable is the XML itself** — so the merge must be reconciled at the
XML level. David hand-edited the XML directly (his PR has no generator).

**Good news:** there are **zero direct entry-level conflicts** — no entry David adds
is one I removed, and vice-versa. The two changesets are largely *disjoint in intent*
(his = surgical coverage; mine = medical-side FP precision + readability). They can be
combined. The work is in doing it without (a) losing either side and (b) re-introducing
bugs.

## ⚠️ The one blocking issue

**David's PR re-introduces all 21 junk-token FPs I just removed.** Because he branched
from the old base, his body_parts still contains `have, they, has, ll, fish, nfl, fees,
hat, gas, pet, com, snap, mar, mars, hp, rap, pad, tail, cuts, bodies, oct` — the
non-anatomy tokens that fire "have repair", "nfl block", etc. If PR #1 merges to master
as-is, the FP bugs come back. **Any merge must drop these from the combined XML.**

## David's changes — itemized (keep / port / watch)

### A. Laterality regex compression — SAFE, functionally identical
`(left|right|bilateral|l|r|bil)` → `(l(eft)?|r(ight)?|bil(ateral)?)` across ~29 patterns.
Matches the same surface set. Accounts for most of his −29/+ patterns. **Keep** (cosmetic;
but note it collides textually with the same patterns I edited for REC-3b/REC-4 — see §E).

### B. New regex entities: `surgical_actions` + `common_actions` — NEW CAPABILITY
Verb-family inflection patterns (`ablat(e[ds]?|ing|ions?)`, `excis(…)`, `repair(ed|ing|s)?`,
…) added to med_surg, obstetrics, placement, new_tech. This is genuinely new surgical
coverage I don't have. **Keep** — but verify against my FP fixtures (the broad verb regex
could re-open FPs my work closed; must run the full FP suite + junk/abbrev probes).

### C. Vocabulary additions — mostly surgical, KEEP (with FP check)
- approach_adj +19: `colonoscopic, transsphenoidal, robotic-assisted, rats, …` — surgical approaches. Keep.
- devices +30: `ahmed valve, da vinci, ventricular assist device, watchman flx, …`. Keep.
- conditions +14, ops_direct +3 (`linx`/`linxes` relocated to a sensible entity).
- **Check:** `rats` (zipf collision?), `da vinci`, `linx` — run through `junk_token_audit.py`.

### D. Vocabulary removals — ALIGNED with my CACHE-2 direction, KEEP
David removes from body_parts: `ahmed, fetal myelomeningocele, prolapse, watchman flx,
linx` — these are CACHE-2 reclassifications (device/condition moved out of body_parts).
He re-adds `ahmed valve`, `watchman flx` to **devices** (correct home). **Keep** — this is
exactly the cleanup direction we discussed with him.

### E. TEXTUAL collision zone — needs careful merge, not auto
David and I both rewrote the **same `ops_combine` laterality patterns**:
- He compressed the laterality alternation (§A).
- I added REC-3b (`op device in/from body`), REC-4 (`<LAT> <ops_lat>`), the `in|from`
  preposition, and the ops_lat restriction.
A line-level git merge of these specific patterns will conflict or silently corrupt.
These ~10 patterns must be merged **by hand / by re-deriving the union of both intents**.

## My changes David's PR does NOT have (must be preserved in the merge)
- 21 junk-token removals (§blocking)
- REC-ABBR: 15 abbrevs demoted ops_direct→ops_combine (l tea / tab / apr FP fix)
- `<LAT> <op>` restricted to `ops_lat` (l tea / l lead / r tab prose-FP fix)
- BP-3/BP-4 disjointness (body_parts ∩ ops/devices = 0)
- Readability: architecture preamble, section banners, per-entity comments
- Test infra: fp_audit/ harnesses, fp_standalone_abbrev_prose, regressed_2026_06_11

## David's test files (non-conflicting, additive)
- `tests/true_positives/surgical_procedures.txt` (+37,838) — his TP benchmark
- `tests/false_positives/false_surgical_procedures.txt` (+799) — his FP set
Both are new files → merge cleanly. **Should be run against the merged grammar** as
additional acceptance gates.

## Recommended merge path (XML-level, no generator dependency)
1. Start from MINE (has all FP fixes + junk cleanup + readability).
2. Port David's additive, non-conflicting changes: approach_adj +19, devices +30,
   conditions +14, ops_direct +3, surgical_actions/common_actions ×7 entities, his
   CACHE-2 removals (already aligned).
3. Hand-merge the §E collision patterns: take the union — his laterality compression
   form, carrying my REC-3b/REC-4/ops_lat additions.
4. Confirm the 21 junk tokens stay OUT.
5. Compile + run BOTH test suites (my FP/regression + his 37k TP / 799 FP) + the
   fp_audit harnesses. Acceptance: my gates stay green AND his TP recall is preserved.
6. Because I maintain the generator, the durable version of steps 2–3 is to port
   David's intent into the generator so the next regenerate reproduces the merged XML.
   (Optional / separate from shipping this XML.)

---

## MERGE EXECUTED (2026-06-12) — results

Built merged XML: my baseline (all FP fixes + junk cleanup + readability) +
David's additive pieces. Compiles clean (v10.9.0). Final gate matrix:

| Gate | Pre-merge (mine) | Merged | Verdict |
|---|---|---|---|
| Madeleine MERGED (medical) | 92.9% | **93.15%** | ↑ (David's surgical vocab) |
| tier1_canonical | 98.5% | 98.51% | flat ✓ |
| false_positives_all | 27/762 (3.54%) | 27/762 (3.54%) | flat ✓ |
| fp_standalone_abbrev_prose (l tea family) | 0 | 0 | held ✓ |
| regression FP-2.b (traumatic amputation) | 0/101 | 0/101 | held ✓ |
| regression junk/abbrev | 0/55 | 0/55 | held ✓ |
| 21 junk tokens in body_parts | none | **none** | held ✓ |
| David TP (surgical) | — | 90.71% (34,321/37,838) | his coverage preserved |
| David FP (surgical) | — | 4.76% (38/799) | clean |

### What was merged in
- David vocab: approach_adj +19, body_parts +25, devices +29, conditions +14,
  ops_direct +2, new_tech/devices +1, obstetrics/ops_direct +1 (91 entries, all
  new & non-junk).
- David's 7 verb-regex entities (surgical_actions / common_actions × med_surg,
  obstetrics, placement, new_tech) + 21 wiring patterns.
- Laterality regex compression (29 patterns) — behavior-identical.

### Two precision conflicts found & resolved (need David's sign-off)
David's `surgical_actions` re-opened two precision holes my work had closed.
Per our alignment ("keep what improves or is neutral; drop what hurts"):
1. **`amputat(e[ds]?|ing|ions?)` removed from surgical_actions** — it fired
   `amputation` standalone, re-opening 61 traumatic-amputation FPs (FP-2.b, which
   deliberately routes `amputation` through ops_restricted). Cost: −11 David-TP
   lines, −3 Madeleine. Net strongly positive.
2. **`anastomo(...|tics?)` narrowed to `anastomo(s(e[ds]?|ing))`** — the `-tic`
   noun sense fired on the diagnoses "anastomotic leak" / "anastomotic stricture".
   The verb sense ("anastomose the bowel") still fires.

All 21 junk tokens I removed stay out (David's PR would have reintroduced them).
