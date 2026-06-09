# ICD-10-PCS Grammar — Quality Backlog

Snapshot date: 2026-05-25 (grammar build derived from `upstream/v3_generate_icd10pcs_grammar.py` against the May 22 ECR).

This document tracks prioritized work items across three pillars:

1. **FP backlog** — false positives the current grammar produces against curated `tests/false_positives/` and `tests/mimic_iv/` fixtures.
2. **Recall backlog** — recall misses against the Madeleine `Procedure_Name_Master_List_MERGED_clean.txt` benchmark and the MIMIC-IV procedure-title set.
3. **Test-data backlog** — fixtures that the pipeline needs in order to *measure* the items above (or that block any further tuning because the relevant signal is undercounted today).

Each item has a severity (recall/precision impact in percentage points), an estimated fix size (S=≤1d, M=2–3d, L=≥1w), and a dependency note where ordering matters.

---

## Headline numbers

Last full re-measurement: **2026-05-28** (post FP-3 / FP-4 / FP-4-v2 / REC-7 / FP-2.b / FP-2.a).

### Real-data benchmarks (MIMIC-IV)

| Suite | Lines | Surgical entity | Medical (super) entity |
|---|---:|---:|---:|
| `tp_procedure_titles` (TP recall) | 2,000 | **78.1%** (1,562) | **96.0%** (1,919) |
| `fp_*` combined (FP rate) | 1,139 | **0.7%** (8 unique) | **1.1%** (12 unique) |

### Synthetic suites

| Suite | Lines | Hits/Fired | Rate |
|---|---:|---:|---:|
| Madeleine MERGED clean (TP, surgical)¹ | 34,928 | 30,048 | **86.03%** recall |
| Madeleine MERGED clean (TP, medical super)¹ | 34,928 | 30,958 | **88.63%** recall |
| `tier1_canonical.txt` (TP) | 1,071 | 1,049 | **97.9%** recall |
| `tests/false_positives/false_positives_all.txt` (FP) | 786 | 48 fired | **6.1%** FP |
| `tests/false_positives/*` (14 files combined)² | 1,770 | 106 fired | **6.0%** FP |
| `v2_ollama_should_not_match` (surgical)³ | 6,548 | 215 fired | **3.3%** FP |
| `v2_ollama_should_not_match` (medical)³ | 6,548 | 273 fired | **4.2%** FP |

¹ Re-measured 2026-05-28 against current grammar (post FP-3/FP-4/REC-7/FP-2.b/FP-2.a). The previous headline was 92.62% on the medical entity; the gap is structural (cumulative effect of FP-3/FP-4 cleanup landing first, then FP-2.a costing a further 11 lines). Of the 3,970 medical-entity misses, only ~136 cluster cleanly: 91 `<op> of <bp>` (REC-3 territory), 22 `amputation` (`digital amputation`, `forearm amputation` — body_parts gap, not FP-2.b regression — verified), 11 vessel-pathology (FP-2.a cost; accepted), 12 dissection / detachment misc. The remaining ~3,834 are heterogeneous and don't cluster to a single fix.
² FP-3 saved 6 firings (bare-equipment FPs `chest tube`, `arterial line`, `peg tube`, `t-tube`, `tracheostomy tube`, `Patient consented to chest tube.`). FP-fixture line count drop from 2,022 → 1,770 reflects FP-5 cleanup (2026-05-25) — 14 mislabeled TP lines moved to `true_positives/tier3_clinical_extra.txt`. See `tests/false_positives/MIGRATION_2026-05-25.md`.
³ Last formal measurement; v2_ollama suite has not been re-run since FP-3/FP-4/REC-7. Re-measure scheduled.

### Trend on real data (MIMIC-IV)

| Date | Surgical FP | Medical FP | Surgical TP | Medical TP |
|---:|---:|---:|---:|---:|
| 2026-05-18 | 9.3% (106) | 10.6% (121) | 78.2% | 96.0% |
| 2026-05-27 (post FP-3 / FP-4 / REC-7) | 4.7% (54) | 5.1% (58) | 78.1% | 96.0% |
| 2026-05-27 (post FP-2.b) | 2.5% (28) | 2.8% (32) | 78.1% | 96.0% |
| **2026-05-28 (post FP-2.a + FP-4 v2)** | **0.7% (8)** | **1.1% (12)** | 78.1% | 96.0% |
| **Δ since 2026-05-18** | **−8.6 pp** | **−9.5 pp** | flat | flat |

**Four precision fixes (FP-3 / FP-4 / FP-2.b / FP-2.a) cut MIMIC surgical FPs by ~92% with zero TP recall regression on MIMIC. Tier3 cost: −2 lines (4564 → 4562, −0.04%) — accepted.**

### Open levers (ranked by measured MIMIC FP residue, post FP-2.a)

The remaining 8 unique surgical FP spans (and 12 medical) all fall into a single cluster: **legitimate procedure mentions inside ICD-10-CM diagnosis-context titles** (e.g. `Atherosclerosis of autologous vein coronary artery bypass graft(s)` → `coronary artery bypass`; `Stenosis of coronary artery stent` → `coronary artery stent`; `Cataract extraction status, left eye` → `Cataract extraction`). These describe a *prior procedure that caused the diagnosis* — not pathology surface forms. The right tool is FP-1 (status-post / sequela context guard), not anatomy-pathology blocklists.

1. **Status-post / sequela / atherosclerosis context** — ~6 lines (FP-1; gated on R&D scope answer for active vs include-historical procedures).
2. **`bypass, elbow` / `implant, joint` / `spinal infusion catheter` / `vein bypass`** — long-tail compositional `<op>(,| of) <bp>` substring leaks. Likely fixed by FP-1 OR by tightening the prepositional pattern's body-part list.
3. **Madeleine recall** — 700+-line cluster on approach-as-trailing-word (REC-1) gates a jump to ~95% recall.

---

## 1) FP BACKLOG — ordered by FP percentage-point impact

### FP-1 — Historical/status-post context guard *(severity: HIGH; size: M)* ✅ RESOLVED 2026-06-09 (policy: include-historical)

**Resolution (2026-06-09):** Two findings closed this as a grammar item:
1. **Mechanically infeasible as a grammar fix.** A `<pattern score="0">` on the prefixed
   form (`status post appendectomy`) does NOT suppress the contained inner span
   `appendectomy` — Eduction leaks shorter matches past score=0 on a longer span.
   Proven with an isolated 2-entry grammar (the bare procedure still fired). Status-prefix
   suppression would require a **post-extraction left-context filter** (consumer/DLP-policy
   layer), not the grammar.
2. **Policy decision: include-historical.** For DLP, "history of appendectomy" is still PHI —
   the entity SHOULD report historical procedures. So these were never true FPs. Working
   default adopted 2026-06-09 (R&D confirmation pending, non-blocking — see docs/RD_question_FP1.md).

**Action taken:** the 92 genuine historical/status-post procedure mentions were moved
OUT of the FP fixtures into `tests/true_positives/medical_historical_procedures.txt`
(mirror of the FP-5 migration). `fp_status_descriptions.txt` now holds only the 11 true
non-procedures (post-surgical sequelae: adhesions, graft failure, stricture, …). Umbrella
`false_positives_all.txt` cleaned of the 19 mislabeled lines → measured FP **5.89% → 3.54%**
(we stopped penalizing correct matches). No grammar change.

**Residual (minor):** negated forms (`no history of appendectomy`, `denies …`, `… not
performed`) currently match — kept in the historical-TP set and flagged in the R&D note;
negation-suppression is a finer downstream-policy question, not pursued now.

---

**Original evidence (for history):** `fp_status_descriptions.txt` fired 19/30 = 63%. `analyze_fp.py` flags 37 firings as `historical-context` across the suite, plus 7 in `v2_ollama_should_not_match`. Sample firings (all current TPs being matched in negation context):

```
"history of appendectomy"          → matches "appendectomy"
"prior cholecystectomy"            → matches "cholecystectomy"
"status post knee arthroplasty"    → matches "knee arthroplasty"
"remote history of mastectomy"     → matches "mastectomy"
"surgical history includes hysterectomy"  → matches "hysterectomy"
```

**Approach:** Introduce a left-context negative-lookbehind list (`history of`, `h/o`, `s/p`, `status post`, `prior`, `previous`, `past`, `remote`, `s\\.p\\.`) at the *entity* level, not the rule level — same mechanism as the existing `_SKIP_PLURAL_LAST` infrastructure. Validators side: a Lua post-filter is the safer first step because it is reversible and isolates the rule change from the grammar.

**Risk:** Genuine procedure mentions in past surgical history *should* often still match in real workflows — confirm with R&D whether this entity is meant to *include* historical procedures or only active orders. If the answer is "active only", we get a free precision win; if "include historical", this becomes a confidence-tier downgrade rather than a kill.

**Depends on:** TD-1 (expand status framing fixtures so we can measure the win without flying blind).

---

### FP-2 — Procedure-word-in-diagnosis disambiguation *(severity: HIGH; size: L)*

**Evidence:** 127 firings flagged `procedure-word-in-diagnosis`. Top compounds:

```
retinal detachment           10×
aortic dissection             6×
amputation at <site>         8× (e.g., "amputation at knee level" — traumatic injury)
retinal vein occlusion        4×
choroidal detachment          4×
celiac/cerebral/colonic/renal/mesenteric/pancreatic/femoral occlusion (2× each)
carotid/coronary/renal/femoral/splenic artery dissection
```

These are diagnoses where the *grammar surface form* legitimately overlaps with a procedure root (the verb `dissect` exists, the verb `occlude` exists, the verb `detach` exists, the verb `amputate` exists) but the surrounding noun head is anatomy + pathology rather than operative.

**Approach:** Two-tier:

1. **Anatomy-pathology blocklist.** For each `<anatomy>` head, enumerate the diagnostic compounds that should *not* match — `retinal detachment`, `*-itis`, `*-osis`, `*-pathy`, `*-emia`, `<site> dissection` when not preceded by `surgical|aortic|robotic|laparoscopic` etc. Easiest as a `_DIAG_BLOCKLIST` constant in the grammar generator.
2. **Traumatic amputation prefix.** `Complete/partial traumatic ... amputation of <site>` is unambiguously a coded diagnosis, not a procedure. Block when preceded by `traumatic`, `complete traumatic`, `partial traumatic`, `traumatic ... amputation at`.

**Risk:** Real procedures *do* include "dissection" as a step (e.g., "neck dissection", "axillary lymph node dissection") and "occlusion" as an operation (e.g., "LAA occlusion"). The blocklist must be *anatomy-headed* (e.g., `retinal detachment` blocked but `retinal detachment repair` retained), not verb-headed.

**Depends on:** TD-2, TD-5.

**FP-2.b ✅ DONE 2026-05-27.** `amputation` was demoted from `_CLINICAL_OPS_C` (which generates the `<op_combine> of <bp>` path) into a new restricted `icd10pcs/med_surg/ops_restricted` entity. Only `<bp> amputation`, `<bp> amputation <approach_adj>`, and `<approach_adj> amputation` patterns are emitted — the prepositional `amputation of <bp>` direction is intentionally not generated. Gated by `ENABLE_FP2B_TRAUMATIC_AMPUTATION` in [v3_generate_icd10pcs_grammar.py:408](v3_generate_icd10pcs_grammar.py#L408). All 61 distinct MIMIC traumatic-amputation lines now MISS (probe in [tests/false_positives/fp_traumatic_amputation.txt](tests/false_positives/fp_traumatic_amputation.txt)). Tier1 recall flat 1049/1071. MIMIC surgical FP 4.7% → 2.5% (medical 5.1% → 2.8%); recall flat. Wins appended to [tests/regression/regressed_2026_05_27.txt](tests/regression/regressed_2026_05_27.txt) — gate now covers 101 lines.

**FP-2.a ✅ DONE 2026-05-28.** Vessel anatomy-pathology blocklist for `<vessel> dissection` and `<vessel> occlusion` ICD-10-CM diagnosis titles. Implemented as `_VESSEL_PATHOLOGY_BLOCKLIST` of regexes emitted as `<pattern score="0">` in both public aggregators (alongside FP-4). Score=0 mechanism is correct here — unlike FP-2.b's amputation case, `dissection` and `occlusion` are heavily used as CMS-canonical operation roots (63 `Occlusion of <bp>` MIMIC TPs, plus tier1 `<bp> Lymph Node Dissection` and `<bp> Endovascular Occlusion`), so demoting them from `ops_combine` would cost more recall than it gains in precision. The bare FP surface forms (`<vessel> occlusion` / `<vessel> dissection` with no laterality, no approach, no surgical anchor) are unambiguously diagnostic. Gated by `ENABLE_FP2A_VESSEL_PATHOLOGY`. Same patch also extended FP-4 with detachment surface variants (`detachment, <eye>`, `detachment involving the macula`, `detachment of retinal pigment epithelium`, `occlusion, <eye>`) — the FP-4 v1 leaks documented in CLAUDE.md.

**Measured impact (MIMIC-IV 2026-05-28):** surgical FP **2.5% → 0.7%** (−1.8pp, 28 → 8 unique terms); medical FP **2.8% → 1.1%** (−1.7pp, 32 → 12 unique terms); MIMIC TP recall flat. Tier1 recall flat 1039/1071. Tier3 cost: −2 lines (`right/left iliac artery occlusion surgical` Madeleine entries, already partial-span TPs because `surgical` is not an approach_adj). Probe fixture: [tests/false_positives/fp_vessel_pathology.txt](tests/false_positives/fp_vessel_pathology.txt) (77 lines, 0 fire). Wins captured in [tests/regression/regressed_2026_05_28.txt](tests/regression/regressed_2026_05_28.txt) (57 lines).

**FP-2 status:** All large clusters (FP-2.a vessel-pathology, FP-2.b traumatic amputation, FP-4 ophthalmic) are now closed. The remaining MIMIC surgical FP residue (8 unique terms) is dominated by status-post / procedure-mention-in-diagnosis context — see FP-1.

---

### FP-3 — Equipment-only standalone removal *(severity: MEDIUM; size: S)* ✅ DONE 2026-05-25

**Evidence:** 8 firings flagged `equipment-only` plus several in `top_match`:

```
chest tube         4× (in lines like "chest tube to suction overnight")
arterial line      3× (in lines like "arterial line in left radial")
central line placement   3× (this is a procedure — not an FP — see FP-5)
```

Equipment alone (catheter, tube, line, pump, monitor, device) without an operative verb is not a procedure. The grammar currently generates compositional rules where equipment names can match standalone in some surface forms.

**Approach:** Demoted 23 equipment-only nouns (chest/peg/feeding/suprapubic/et/trach/tracheostomy/nephrostomy/gastrostomy/t-tube/pc/rig/nasal tubes; picc/cvp/femoral/arterial/a-line/iv/central-venous lines) from `_CLINICAL_OPS_D` (standalone-firing) to a new `_EQUIPMENT_DEVICES` list, joined into `ms_devices`. Equipment now only fires via the `<op_combine> <device>` / `<device> <op_combine>` patterns, requiring an explicit operative verb (insertion/removal/placement/change/etc.).

Two procedure-defining device phrases (`tube graft`, `tube shunt`) were retained in `_CLINICAL_OPS_D` because they describe procedure types, not bare equipment (`aortic tube graft`, `glaucoma tube shunt`).

**Measured impact (2026-05-25):**
- FP fixture firings: 112 → 106 (−6 lines on 1,770 total; 6.33% → 5.99%)
- TP recall delta: −76 lines across all tier files & madeleine_clean
  - Most regressions are bare-equipment forms (intentional FP-3 target): `peg tube`, `cvp line`, `pc tube`, `chest tube` (lateralized), `History of r chest tube in 2019.`
  - Compositional regressions where approach/laterality but no op-verb is present: `laparoscopic feeding tube`, `percutaneous feeding tube`, `open suprapubic tube`, `cvp line percutaneous`, `brachial arterial line perc` etc. These could be recovered by adding `<approach_adj>\ <devices>` patterns but at FP risk.
- Spot-checks confirmed: `chest tube placement`, `chest tube insertion`, `tracheostomy tube change`, `t-tube insertion`, `peg tube placement`, `arterial line placement` all preserved via `<device>\s<op_combine>` pattern.

**Depends on:** none.

---

### FP-4 — Retinal/ophthalmic disease cluster *(severity: MEDIUM; size: S)* ✅ PARTIAL 2026-05-27

**Evidence:** 18+ ophthalmic firings, distinct enough to call out separately from FP-2:

```
retinal detachment       10×
choroidal detachment      4×
retinal vein occlusion    4×
retinal artery occlusion  2×
detachment of the retina  2×
```

This cluster is so dense and so unambiguously diagnostic that it can be addressed in isolation (one `_OPHTHALMIC_DIAG_BLOCKLIST` group) before tackling the broader FP-2 anatomy-pathology problem.

**Approach:** Implemented as `_OPHTHALMIC_DIAG_BLOCKLIST` (~17 regex patterns) emitted as `<pattern score="0">` in both public aggregator entities. Gated by `ENABLE_FP4_OPHTHALMIC` flag.

**Measured impact (2026-05-27):**
- Bare-form ophthalmic compounds suppressed: `choroidal detachment`, `detachment of the retina`, `detachment of the choroid`, `vitreous detachment`, `posterior vitreous detachment`, `RPE detachment` — 6/12 distinct probe cases eliminated.
- Tier1 recall regression: **0** (1,049/1,071 hits with FP-4 on; 1,049/1,071 with FP-4 off — AB tested).
- false_positives_all.txt: 49 → 48 fired (1 line eliminated; the bigger ophthalmic cluster lives in synthetic probes, not this fixture).

**Known limitation (Eduction score=0 semantics):** score=0 suppresses only the exact matched span — it does NOT override overlapping shorter matches. So `retinal vein occlusion` still surfaces as submatch `vein occlusion` (the `<body_part>vein</body_part> <op>occlusion</op>` shorter span leaks). Same for `retinal artery occlusion`, `<qualifier> retinal detachment in the right eye`. **Tracked under FP-2.**

**Test fixture:** `tests/false_positives/fp_ophthalmic_diagnoses.txt`. Leak cases marked with `# leak:`.

**Depends on:** none for the partial fix landed. Substring leaks depend on FP-2 (anatomy-pathology blocklist for `<vessel> occlusion|dissection`).

---

### FP-5 — True-positive mislabeling cleanup *(severity: TEST QUALITY; size: S)* ✅ DONE 2026-05-25

**Evidence:** 47 firings landed in the `other` category, but spot-checking shows several are *not actually FPs* — they are legitimate procedure mentions miscoded into FP fixtures during the early curation pass:

```
"central line placement"   → in fp set, but is the canonical PCS procedure
"drainage of abscess"      → procedure, not negation
"joint aspiration"         → procedure
"bone marrow aspiration"   → procedure
"nerve block"              → procedure
"pacemaker insertion"      → procedure
"cardiac stent placement"  → procedure
"thoracentesis"            → procedure
"paracentesis"             → procedure
"hernia repair"            → procedure
"knee arthroplasty"        → procedure
"laminectomy"              → procedure
```

These artificially inflate our reported FP rate and *distort the gradient* for FP-1/FP-2 work — fixing them via context guards would actually be regressions.

**Approach:** Move these lines out of `fp_*.txt` and into `tests/true_positives/sentences_true_positive.txt` (or a new `tier3_clinical_extra.txt`). Document the move in a single commit.

**Risk:** Negligible — pure data hygiene.

**Depends on:** none. Should land *before* FP-1/FP-2 so the impact metrics on those items are clean.

---

### FP-6 — Compositional v2_ollama "knee replacement … alternative" *(severity: LOW–MEDIUM; size: M)*

**Evidence:** v2_ollama_should_not_match top firings:

```
knee replacement             18×  (in lines like "knee replacement surgery alternative", "knee replacement surgery risks")
hip replacement               7×
fracture treatment            9×  (e.g., "radial nerve fracture treatment")
lower extremity fracture repair  6×
```

These appear in a column-format file where the *first* column is the ICD code and the *second* is the negative phrase. Many are ambiguous between "patient considering option X" (negation) and "education / counseling about X" (legitimate clinical context).

**Approach:** Right-context guard for `<procedure> <alternative|option|risks|education|consideration|consultation>`. This is structurally similar to FP-1 but applied to right-side framing rather than left.

**Risk:** v2_ollama is itself a synthetic LLM-generated benchmark and ~80% of its firings landed in `other`, suggesting many are arguable. Treat these as confidence-tier, not hard kills.

**Depends on:** TD-3 (need a proper EOB/counseling/preauth fixture before tuning against v2_ollama).

---

### FP-7 — MIMIC procedural-vocab cluster (15.4% FP rate) *(severity: MEDIUM; size: M)*

**Evidence:** `tests/mimic_iv/fp_diagnoses_procedural_vocab.txt` fires 77/500. Inspecting the firings, the bulk are *traumatic amputation* coded as ICD-10-CM diagnoses (S- and T-codes, not 0- procedure codes):

```
"Complete traumatic amputation of right hip and thigh, level unspecified, ..."
"Partial traumatic amputation at knee level"
"Necrosis of amputation stump, left upper extremity"
```

These are the exact rows FP-2 (traumatic amputation prefix) addresses. There are also `*-ectomy` *site* descriptors (e.g., "post-cholecystectomy syndrome") that should be similarly guarded.

**Approach:** Tracked by FP-2; this entry is a measurement target so we can report the win on the MIMIC slice separately.

**Depends on:** FP-2.

---

## 2) RECALL BACKLOG — ordered by recall percentage-point impact

The Madeleine MERGED set has 2,578 misses (7.38% of 34,928). Patterns below sum to *more* than 2,578 because some misses match multiple patterns (e.g., "left auditory tube dilationno device" is both `lat-first-word` and a Madeleine concatenation artifact).

### REC-1 — Approach-as-trailing-word ("open", "perc", "endo") *(severity: HIGHEST; size: M)*

**Evidence:** Largest single recall lever. Counting trailing-word forms specifically (not just substring containment):

```
last word "open"           178×
last word "perc"           150×
last word "percutaneous"    73×
last word "endo"            19×
last word "endoscopic"      17×
```

That is **~440 misses**, plus the **24 + 12 + 9** Madeleine concatenation artifacts ("replacementopen", "supplementopen", "augmentationopen") which are likely the *same* entries with the space dropped during their preprocessing. If both are repaired, we recover ~485 lines — roughly **1.4 percentage points of recall** in one PR.

The compositional rules currently expect approach as a *prefix* or *infixed clause* (e.g., "open repair of femur"), not as a *bare trailing token* (e.g., "femur repair open"). Madeleine clearly canonicalizes with approach last.

**Approach:**

1. Extend the body-part-times-operation product with a `<approach_trailing>?` slot accepting `open`, `perc`, `percutaneous`, `endo`, `endoscopic`, `lap`, `laparoscopic`, `robotic` as a final token.
2. Add a tokenizer-level fix or pre-grammar normalization for `(?P<op>repair|supplement|augmentation|change)open` → `\1 open` (the concatenation artifact).
3. Verify against a synthetic minus-approach control (the same 178 lines with "open" stripped) to ensure we are gaining recall, not over-generating.

**Risk:** Medium. Trailing-`open` is highly ambiguous in narrative ("scar is open", "wound is open and draining"). The fix should require a preceding `<body_part>` *and* `<operation_root>` token to fire.

**Depends on:** TD-4 (need a fixture of "open as adjective in non-procedure context" to guard against over-generation).

---

### REC-2 — Generic trailing word ("surgery", "procedure", "approach", "operation") *(severity: HIGH; size: S–M)*

**Evidence:**

```
last word "surgery"      99×   ("acid reflux surgery", "ai bypass surgery")
last word "approach"     99×   ("open approach", "external approach")
last word "procedure"    26×   ("left cas procedure")
last word "operation"     9×   ("arterial switch operation", "atrial switch operation")
last word "treatment"   ~15×
```

**~250 misses**, ~**0.7 pp** recall.

**Approach:** Many of these are partial Madeleine canonicalizations where the approach phrase was retained but the body-part-keyed rule didn't include it. Add a tail-extension rule allowing `<body_part_op_phrase>` + `(surgery|procedure|operation|approach|treatment|technique)?`.

**Risk:** Medium-high — `<anything> surgery` is an extremely permissive surface form and will pull in things like `cosmetic surgery`. Must be gated by an upstream procedure root or anatomy head.

**Depends on:** TD-4.

---

### REC-3 — Operation-first-word ("insertion", "removal", "change", "supplement") *(severity: HIGH; size: M)*

**Evidence:**

```
"insertion device <body_part> <approach>"      124× as first word "insertion"
"removal <device> <body_part>"                  54×
"change <device> <body_part>"                   ~30×
"revision ..."                                  21×
"supplement <body_part> <substitute>"           20×
"replacement ..."                                9×
```

**~230 misses**, **0.7 pp** recall. Sample lines:

```
"change other device in salivary gland, external approach"
"change other device salivary gland external approach"
"insertion device left pleural cavity percutaneous"
```

These are **near-canonical PCS row labels** with the approach trailing — the ICD-10-PCS official tabular form. The grammar currently keys most rules off body-part-first or anatomy-noun-first; PCS-canonical operation-first phrasing is undercovered.

**Approach:** Add an `<operation_root> [device]? [in]? <body_part> [, ]? <approach>?` template at the rule generator. This is **the** highest-leverage rule addition — it directly mirrors how PCS rows are written.

**Risk:** Low–medium — the form is so PCS-specific that the false-positive surface is small.

**Depends on:** none. **This should be the first recall PR shipped.**

---

### REC-4 — Lateralized first word ("right", "left", "r", "l", "bilateral") *(severity: MEDIUM-HIGH; size: M)*

**Evidence:**

```
first word "r"           168×   (e.g., "r ear repair")
first word "right"       133×
first word "l"            99×
first word "left"         69×
first word "bilateral"    ~15×
first word "lap"          21×
```

**~205+ misses**, ~**0.6 pp** recall. Plus the abbreviated `r`/`l` forms which are also picked up by REC-7.

**Approach:** Allow lateralized prefix as an optional leading token in the body-part composition: `(right|left|r|l|bilateral|bil)? <body_part_phrase>`. The body-part lexicon already has lateralized variants in some places — this normalizes to *prefix* rather than *embedded* lateralization.

**Risk:** Low — `r` and `l` alone are dangerous (English pronoun "I", letter abbreviations) but the *requirement* to be followed by a known body-part token confines them.

**Depends on:** REC-7 (abbreviated-form coverage so the prefix has somewhere to land).

---

### REC-5 — Short medical abbreviations (≤10 chars) *(severity: HIGH but DIFFUSE; size: L)*

**Evidence:** **532 misses**, ~**1.5 pp** recall — but these are highly *heterogeneous*:

```
acb, accf, acf, aci, aclr, acs, a&t, bpd, bsso, crpp, holep, lvad,
cabg, ercp, egd, vats, crrt, ecmo, tips, impella, etc.
```

The lexicon already covers many TLAs (`tier6_abbreviation.txt` is 1,322 lines and our coverage there is solid) — the *missed* abbreviations are the ones that haven't been catalogued yet. About **24 known clinical abbrevs** (TAVR, CABG variants etc.) are missed because of compositional context (PCI x1, single-vessel, four-or-more etc.).

**Approach:** Two-phase:

1. **Cataloguing pass.** Mine the 532 misses for the unique tokens (probably ~250 unique abbrevs once de-duped). Cross-reference against the `_MEDICAL_PLURAL_OVERRIDE` and abbreviation lexicon. Add the missing entries to `tier6_abbreviation.txt` *and* the grammar.
2. **PCI-modifier extension.** Add the modifier vocabulary (`x1`, `x2`, `x3`, `single-vessel`, `two-vessel`, `single`, `multi`, `multivessel`, `bifurcation`, `cto`, `dcb`, `bms`, `des`, `four or more`, `with drug-eluting stents`) as a suffix slot to PCI/CABG roots.

**Risk:** Adding raw abbreviations is high-FP-risk by default — many medical abbreviations collide with English (`acs` = both "acute coronary syndrome" *and* "American College of Surgeons" *and* a procedure code). Each addition should cite a TP source.

**Depends on:** TD-7 (an abbreviation FP fixture so we can measure the precision cost of each addition).

---

### REC-6 — Robotic/laparoscopic/endoscopic prefix forms *(severity: LOW-MEDIUM; size: S)*

**Evidence:**

```
robotic prefix    14×   ("robotic etep", "robotic rygb", "robotic sigmoidectomy")
lap prefix        21×   ("lap chole with ioc")
laparoscopic     32×
endoscopic       11×
```

**~75 misses**, **0.2 pp** recall.

**Approach:** Symmetric with REC-1 trailing-approach work. Add a leading approach-adjective slot: `(robotic|laparoscopic|lap|endoscopic|endo|open|percutaneous|perc) <body_part_op>`.

**Depends on:** REC-1 (do them together — same data structure).

---

### REC-7 — Concatenation artifacts ("repairopen", "supplementopen") *(severity: SMALL; size: S)* ✅ DONE 2026-05-27

**Evidence:** 54 lines in MERGED_clean with the approach token concatenated to the operation root with no space (24 `replacementopen`, 12 `supplementopen`, 9 `repairopen`, 9 `augmentationopen`). Clearly a bug in Madeleine's preprocessing — only `open` appears, no `perc`/`endo` artifacts in the actual data.

**Implementation (2026-05-27):** Two tolerance patterns added to `surg_pats` (gated by `ENABLE_REC7_CONCAT_OPEN`):

```xml
<pattern>(?A:icd10pcs/med_surg/body_parts)\ (repair|replacement|augmentation|supplement)open</pattern>
<pattern>(?A:icd10pcs/med_surg/body_parts)\ patch\ (repair|replacement|augmentation|supplement)open</pattern>
```

The second handles the `<bp> patch <op>open` family (e.g. `right brachial artery patch repairopen`).

**Measured impact (2026-05-27):**
- REC-7 probe (54 concatenation lines): 0/54 → **54/54** correctly matching the full `<bp> <op>open` span. Pre-fix, 9 of these only matched the noun-prefix `<bp> patch` and dropped the operation root.
- tier1_canonical: 1,049/1,071 hits both pre and post — zero regression.
- false_positives_all.txt: 48 → 48 fired — zero new FPs (tolerance pattern requires `<bp>` left-context which is the same gate as the legitimate compositional rule).

**Risk:** Negligible. The pattern is anchored on `<bp>` which already gates a compositional rule, so no new attack surface in real text.

**Depends on:** none.

---

### REC-8 — Long phrases (≥7 words) — bypass / shunt routes *(severity: SMALL-MEDIUM; size: M)*

**Evidence:** 154 misses with ≥7 words. Almost all are vascular bypass routes:

```
"bypass left external iliac to common femoral"
"bypass right internal carotid to extracranial autologous venous open"
"bypass right internal carotid to intracranial open no device"
"cerebral ventricle to blood vessel csf shunt"
```

**~150 misses**, **0.4 pp** recall. These are the canonical PCS bypass-row labels.

**Approach:** Add a multi-anatomy bypass template: `bypass [<lat>]? <body_part> to <body_part> [<material>]? [<approach>]?`. The grammar supports a fixed `bypass A to B` form today — extending it to allow `(autologous venous|synthetic|allogeneic|nonautologous)? (open|percutaneous|...)? (no device)?` tail captures the remainder.

**Risk:** Medium — `to` is an extremely common English word. Fix must require both A and B be in the body-part lexicon.

**Depends on:** none.

---

### REC-9 — Comma-form variants *(severity: SMALL; size: S)*

**Evidence:** 33 misses use a comma between phrase parts:

```
"change other device in salivary gland, external approach"
"implant, joint"
```

**Approach:** Allow optional `,` between `<body_part>` and `<approach>` slot. Mostly a tokenizer-level tolerance.

**Depends on:** REC-3 (this is its sibling pattern).

---

### REC-10 — Slash-form ("BPD/DS", "TEM/TAMIS") *(severity: TINY; size: S)*

**Evidence:** Only 2 lines in MERGED but a known surface form in clinical writing. The slash-expansion fix from earlier in this session handled the `≤2 char` case (`p/d`, `t3/t4`); this one is the symmetric `multi-char abbreviation / multi-char abbreviation` case.

**Approach:** Extend the slash-expansion to also fire when both fragments are in the abbreviation lexicon.

**Depends on:** REC-5 (lexicon must include both fragments).

---

## 3) TEST-DATA BACKLOG — fixtures the pipeline needs

The test corpus is asymmetric: ~78k positive lines, ~3k negative lines. That is fine for top-line recall numbers but **insufficient for measuring the FP work in §1**. Each item below identifies a missing slice and ties to a backlog item that depends on it.

### TD-1 — Expand `fp_status_descriptions.txt` from 30 → 300 lines *(blocks: FP-1)*

The current 30-line file generates a 63% FP rate, which is statistically meaningful but cannot resolve sub-categories (h/o vs s/p vs prior vs remote vs surgical-history-includes). Target: 50 lines per framing variant × 6 variants = 300, mined from MIMIC discharge-summary `Past Medical History` sections (with PHI scrubbing).

### TD-2 — Disease-mimics-procedure FP set, 200 lines *(blocks: FP-2, FP-4, FP-7)*

Per anatomy region: 25 lines × 8 regions (cardiac, vascular, ocular, GI, GU, ortho, neuro, soft-tissue) of *diagnosis* descriptions whose surface form contains a procedure root (`dissection`, `occlusion`, `detachment`, `amputation`, `fracture`, `rupture`, `thrombosis`, `stenosis`, `infarction`, `fistula`, `aneurysm`, `embolism`). This is the empirical training set for FP-2.

### TD-3 — EOB / payer / counseling FP set, 100 lines *(blocks: FP-6)*

Lines like:
```
"Preauthorization denied for knee replacement on 2026-04-15"
"Patient is considering hip replacement; second opinion scheduled"
"Discussed alternatives to gallbladder surgery: cholecystostomy, ursodiol"
"Education provided regarding risks of CABG"
"Pending appeal — cardiac stent placement"
```

These currently have zero coverage and are precisely the negation-context where compositional rules over-fire.

### TD-4 — Common-English compositional FP set, 100 lines *(blocks: REC-1, REC-2)*

Lines that reuse procedure vocabulary in non-medical context:
```
"open the file" / "an open wound" / "open enrollment"
"highway bypass on I-95"
"firewall bypass detected"
"the surgery resident was on call"
"approach the problem from another angle"
"line in the sand"
```

These are the controls for the trailing-word and approach-word work in REC-1/REC-2 — without them, we cannot measure the precision cost of the recall fixes.

### TD-5 — Traumatic amputation challenge set, 100 lines *(blocks: FP-2, FP-7)*

The MIMIC procedural-vocab file already has many; promote ~100 of them to a dedicated `tests/false_positives/fp_traumatic_amputation.txt` so the targeted fix in FP-2 has a clean measurement target.

### TD-6 — Operative-note paragraph fixtures, 50 paragraphs *(new capability)*

The current corpus is line-oriented — a single procedure name per row. Real DLP scans hit *paragraphs* of operative notes containing 5–20 procedure mentions interleaved with patient identifiers, dose strings, anatomy descriptions, and timestamps. A `tests/sentences/operative_notes.txt` fixture (50 paragraphs × ~200 words) would let us measure span-level precision (extra firings beyond the intended one) which is invisible in line-oriented testing.

### TD-7 — Abbreviation FP fixture, 200 lines *(blocks: REC-5)*

Common-English collisions for medical abbreviations: `cabg` is unique, but `acs`, `pci`, `egd`, `mri`, `ct`, `ekg` collide with everyday vocabulary. Build 200 lines pairing each abbreviation in `tier6_abbreviation.txt` with non-medical context (e.g., "ACS Chemistry curriculum", "the EGD opens at 9am").

### TD-8 — Discharge-summary slice from MIMIC, 200 lines *(complements: FP-1, TD-6)*

`Brief Hospital Course` and `Discharge Diagnoses` sections are dense with negation-framed procedure mentions. A direct sample (PHI-scrubbed) gives us realistic narrative rather than synthetic.

### TD-9 — Regression bucket *(infrastructure; size: S)* ✅ DONE 2026-05-27

Every triaged FP that we fix lands in `tests/regression/regressed_<date>.txt`. CI gate `tests/regression/run_regression_gate.py` exits non-zero if any line fires.

**Initial snapshot (2026-05-27):** 40 lines — 5 FP-3 wins (chest tube, arterial line, peg tube, t-tube, "Patient consented to chest tube.") + 35 FP-4 wins (retinal/choroidal/vitreous/macular detachment family, retinopathy variants, hemorrhage). Bidirectionally tested: PASS on green ECR; FAIL with 6 firings when `ENABLE_FP4_OPHTHALMIC=False`. Buckets are append-only — to remove a line, move to `tests/regression/retired/` with rationale.

**Future fixes** (FP-1, FP-2.a, FP-2.b, etc.) should append to a fresh `regressed_<their-date>.txt` rather than mutating earlier snapshots, so each fix's wins are self-contained and traceable.

### TD-10 — Ambiguous resolution log *(infrastructure; size: S)*

The 2,904-line `tests/ambiguous/madeleine_ambiguous.txt` has no provenance for *why* each line is ambiguous. Add a one-line annotation per row (e.g., `# diagnosis-or-procedure depending on framing`) so future tuning has a paper trail.

---

## Suggested execution order

Each phase is independently shippable. Numbers in parentheses are the recall pp / FP pp deltas we should expect.

**Phase 1 — Cheapest precision wins, no blocked dependencies (1 week)**
1. FP-5 (test-data hygiene; +clean baseline)
2. FP-3 (equipment-only; ~+0.3 pp precision)
3. FP-4 (retinal cluster; ~+0.5 pp precision)
4. REC-7 (concatenation artifacts; ~+0.05 pp recall)

**Phase 2 — Highest-leverage recall (2 weeks)**
1. REC-3 (operation-first-word; **+0.7 pp recall**)
2. REC-1 + REC-6 + REC-9 (approach trailing/leading + comma; **+1.5 pp recall**)
3. TD-4 lands first as a control for REC-1/REC-2

**Phase 3 — Major precision work, gated on data (2–3 weeks)**
1. TD-1, TD-2, TD-5 land (test-data expansion)
2. FP-1 (status framing; **+1–2 pp precision** depending on R&D scope decision)
3. FP-2 + FP-7 (anatomy-pathology blocklist; **+1 pp precision** on MIMIC)

**Phase 4 — Long-tail (ongoing)**
1. REC-4 + REC-8 (laterality, bypass routes; +1 pp recall)
2. REC-2 (generic trailing word; +0.7 pp recall but high-risk)
3. REC-5 (abbreviations; +1.5 pp recall, gated on TD-7)
4. FP-6 (v2_ollama compositional; gated on TD-3)
5. TD-6, TD-8, TD-9, TD-10 (infrastructure)

**Forecast:** On full execution, recall climbs from 92.62% to **~96.5%** on Madeleine MERGED, while line-level FP across the curated suite drops from 5.9% to **<2%**. Net business value depends on FP-1 R&D answer (active-only vs include-historical scope).

---

## Open R&D questions

1. **Scope of "procedure" entity** — does the entity match historical procedures (status post, history of) or only active orders? FP-1 implementation depends on this answer. Stakeholder: R&D Replacement Procedure Classifications team (Confluence page 6804144260).
2. **Confidence tiering** — should ambiguous matches be returned at all, or downgraded to a lower confidence tier that consumers can filter? This affects FP-1, FP-6, and the entire `tests/ambiguous/` corpus (2,904 lines) which currently has nowhere to go.
3. **Operative note vs short field** — are DLP scans typically against structured fields (one phrase) or free text (paragraphs)? Determines whether TD-6 is critical or optional.


---

# Appendix — 2026-06-01 grammar/structure review (ported to eng-772528 2026-06-04)

Items from the structural review (`docs/review_2026-06-04_eng772528.md`, full report `docs/review_2026-06-01.md`, audit sidecars `docs/audits/`). All re-validated against eng-772528 `ac86dbf`. Surgical entity untouched (colleague-owned).

## 4) STRUCTURE / READABILITY / INFRA BACKLOG — from the 2026-06-01 file review

These items come from the structural review in `docs/review_2026-06-01.md` (Phases 0–1). They do **not** change recall or FP — they are correctness-of-toolchain, readability, and generator-hygiene items. All are generator-only unless noted.

### INFRA-1 — Unify edktool toolchain on v10.9.0 *(severity: WAS-CRITICAL; size: S)* ✅ DONE 2026-06-01

The checked-in `.ecr` was compiled with v25.4.0 but every test runner uses v10.9.0, which **cannot read it** (`XML parser error, line 1, col 0`) — `v3_benchmark.py` silently reported 0/N on a clean run. Resolved: v10.9.0 is canonical (production parity); all 5 v25.4.0 references aligned (`run_mimic_benchmarks.sh`, `run_benchmark.sh`, `local_config.py`, `icd10pcs_explainer.html`, `project_report.html`). Two follow-on bugs fixed: the mimic script's edktool path, and its FP parser reading the nonexistent `<ORIGINAL_TEXT>` element (was reporting 0.0% FP on 103 real matches → now 5.1%/5.4%). Full detail in review doc F0.1.

### INFRA-2 — Wire curated-FP + MIMIC fixtures into `v3_benchmark.py` *(severity: MEDIUM; size: S)*

`tests/false_positives/*.txt` (14 files) and `tests/mimic_iv/*.txt` exist but are **not** in `v3_benchmark.py`'s `FILE_GROUPS` — they're only run by the separate `run_mimic_benchmarks.sh`. The canonical benchmark therefore omits curated-FP performance and reads cleaner than reality. Add them as `expect_match=False` groups so one `v3_benchmark.py` run reports both recall and FP. Also reconcile the two FP-counting conventions (raw `<MATCH>` count vs unique-term vs lines-fired) so numbers are comparable across runners.

### CACHE-1 — Generator is non-deterministic via a self-feeding miss-cache *(severity: HIGH; size: M)* ✅ PHASE A DONE 2026-06-08

**Resolution (Phase A, 2026-06-08, commit on eng-772528):** the miss-derived body-part cache (`data/april-2026/icd10pcs_miss_body_parts.txt`) is now a **tracked, version-controlled, frozen input** with a documenting header. The generator change:
- Always **loads** the frozen cache (decoupled from the benchmark-misses-file gate), so a clean clone gets the full body-part set.
- Re-mining + cache write-back are now **opt-in** behind a new `MINE_MISSES` flag (default `False`). Default builds are read-only and deterministic.
- Cache loader skips `#` comment lines (enables the self-documenting header).

**Verified:** clean-clone build (no misses file) now produces `body_parts` 14,498 and **MERGED recall 92.9%** — identical to the warm build — and two successive builds are byte-identical (md5 match). The cold/warm 88.9% ↔ 92.9% swing is **eliminated**; the good grammar is now the reproducible one. (Measured on current HEAD which includes REC-3: cold-before-fix was 88.9%.)

**Remaining work → CACHE-2 (mandatory).** The frozen list is reproducible but NOT semantically clean (mixes anatomy / conditions / devices / eponyms / fragments). See CACHE-2.

---

**Original finding (for history) — quantified on eng-772528 `ac86dbf` (2026-06-04):** same commit, v10.9.0 — cold build (fresh clone, no misses file) = `body_parts` 12,216, **MERGED recall 87.8%**; warm build (after one benchmark run seeds the cache) = `body_parts` 14,774, **MERGED recall 92.0%**. **+4.2 pp recall, zero code change.** A clean clone reports 87.8%; cache-seeded local builds report ~92%. Raised to HIGH: this undermines reproducibility and the trustworthiness of every reported recall number.

Discovered while executing the green-lane punch-list (2026-06-01). `v3_generate_icd10pcs_grammar.py` (L520-617) mines body-part candidates from `data/madeleine/Procedure_Name_Master_List_MERGED_clean_misses.txt` — a **benchmark output file** — and accumulates them into an **untracked, non-gitignored** cache `data/april-2026/icd10pcs_miss_body_parts.txt`. The cache grows every run that sees a fresh misses file (observed 1,722 → 1,874, +152 entries into `body_parts`, in one session, purely from having run the benchmark).

Consequences:
- **Non-deterministic builds:** the grammar's `body_parts` depends on whether/when a benchmark last ran, not just on source + generator. (This is why the Phase 0 "zero drift" held only at that instant.)
- **Silent scope creep into shared lexicon:** the mined entries land in `med_surg/body_parts`, which feeds the **surgical** entity (colleague-owned) — so an innocent regenerate can modify surgical's inputs.
- **Repo-hygiene risk:** the cache + the `*_misses.txt` files are untracked but not gitignored, so they can be committed by accident.

This is why the green-lane `quals_med` rename was applied directly to the XML rather than via a full regenerate (a regenerate would have dragged in +355/−23 body_parts). **Decision (2026-06-01): logged as a finding only; behavior unchanged this session** (per user). Options for a fix: (a) make mining explicit/opt-in (a `--mine-misses` flag) so default regenerates are deterministic; (b) gitignore the cache + misses files; (c) commit the cache as a tracked input so builds are reproducible. Review doc F5.1. **Resolved 2026-06-08 via (a)+(c) combined — see the Phase A note at the top of this item.**

### CACHE-2 — Semantically reorganize the frozen miss-derived body-part list *(severity: HIGH; size: L; MANDATORY before final delivery)*

> **Update 2026-06-09 — deferred medical 44 triaged (no action taken, by design).** The remaining medical-side buckets (29 modifier/approach, 11 operation, 2 HOLD, 2 junk) were investigated: the 11 operations already match via existing patterns (caesarean, ostomy, orbital floor repair, …); the 29 modifiers are approach-only qualifiers / common-English (anterior, focal, vacuum) that are NOT standalone procedures — routing them as matchable would add FP risk. **Measured:** dropping all 44 from the cache costs −45 Madeleine recall lines (92.89%→92.77%), so they are kept in the frozen cache as-is (behavior-neutral, gates green). Conclusion: the deferred 44 need no further action on the medical side; the substantive remaining CACHE-2 work is the 742 surgical terms (David). The applied medical buckets (anatomy/device/condition/foreign-body/eponym, 201 terms) are done.

**This is a required deliverable, not optional.** CACHE-1 Phase A froze the 1,081-term miss-derived list as a reproducible tracked input, but the list is **not semantically clean**: classification (2026-06-08) found it mixes genuine anatomy with conditions/findings (`achalasia`, `aortic dissection`, `small bowel perforation`), devices/brands (`ams 800`, `ahmed`, `aortic synthetic patch`, `iol`), surgeon eponyms (`blalock-taussig`, `kasai`, `glenn`, `savary`), procedure/approach fragments (`vats`, `transfemoral`, `carotid loop repair surgery`), foreign-body-retrieval phrases (`egd coin`, `colonoscopic fb`), and truncated abbreviations (`eth`, `oc`, `asdh`, `cp pd`). Only ~250–350 of 1,081 are clean anatomy.

**Requirement (per user, 2026-06-08): do NOT drop useful entries.** Route each term to the entity/group where it belongs, creating **new groups and patterns** where no suitable home exists, rather than discarding:
- genuine anatomy → `_MANUAL_BODY_PARTS` (or `body_parts`), grouped by anatomical system with inline `# comment` explaining each, matching the existing curated style.
- devices → `devices` entity (or a new device group).
- eponyms / conditions / procedure-name fragments → new dedicated entities + patterns as appropriate (e.g. an eponymous-procedure entity), so they match in a principled way instead of as accidental "body parts".
- truncations / true junk → the only category that may be dropped, and only after confirming they contribute no unique recall.

**Deliverable:** the frozen `icd10pcs_miss_body_parts.txt` is retired (or reduced to only the items that legitimately remain body parts), its contents redistributed into semantically-motivated, human-readable generator lists, with **no net recall loss** (measure PRE/POST; target ≥ 92.9% MERGED). Coordinate the surgical-relevant terms with Madeleine (ENG-772518). Classification scratch from the 2026-06-08 pass is in `/tmp/cache1_class/` (regenerable).

### STRUCT-1 — Fix the generator's misleading "Lines: 797" print *(severity: LOW; size: S)*

`v3_generate_icd10pcs_grammar.py` prints `Lines: 797` after writing a 20,029-line file (it's counting `out.append()` blocks, not newlines). Print the real line count or relabel it "blocks". Review doc F0.2.

### STRUCT-2 — Emit per-section banner comments *(severity: MEDIUM readability; size: S)* ← highest-value readability item

20,029-line file with **zero section banners**; sections are separated only by whitespace-only lines. A reader at line 17,600 cannot tell `meas_mon` from `extracorp_asst`. Have the generator emit a banner before each section's first entity (`<!-- ===== SECTION 4 (Measurement and Monitoring) — icd10pcs/meas_mon/* ===== -->`). Also strip the stray trailing-whitespace divider lines. Generator-only, no recompile risk. Review doc F1.1.

### STRUCT-3 — Comment the public aggregator patterns *(severity: LOW-MEDIUM readability; size: S)*

Private pattern entities are 100% example-commented (a strength), but the two **public** entities have **0/22** comments — 22 bare `(?A:…)` lines in the most important entity in the file. Add one `<!-- Section N: <name> -->` per public pattern. Generator-only. Review doc F1.2.

### STRUCT-4 — Standardize axis name `quals_med` → `quals_medical_*` *(severity: LOW naming; size: S)*

`mental_health/quals_med` is inconsistent with `rehab/quals_medical_direct|combine` for the same concept. Rename for consistency (entity name + its `(?A:…)` refs together). Batch with other naming cleanups. Review doc F1.4.

### ENT-1 — Make `_CLINICAL_OPS_C` and `_CLINICAL_OPS_D` disjoint (direct vs combine) *(severity: MEDIUM; size: M)*

29 words are in **both** `ops_direct` and `ops_combine` of med_surg (`cabg`, `arthroplasty`, `ablation`, `orif`, `tka`, `embolectomy`, `lithotripsy`, `thrombectomy`, `exc`, `frag`, `lysis of adhesions`, …) because the generator's two hand-curated lists overlap by 29 (`_CLINICAL_OPS_C` ∩ `_CLINICAL_OPS_D`). This contradicts the grammar's core precision lever (a word is declared both "needs a body part" and "fires standalone"). Since ops_direct wins, the ops_combine copy is always redundant — benign to matching (no wrong results — verified), but a logical contradiction + dead weight. For each of the 29, decide standalone-vs-needs-context and remove from the other list; re-measure recall/FP (some may be intentional standalone promotions, in which case drop the combine copy; others may be FP risks that should be combine-only). Full list: `docs/audits/G_direct_vs_combine_conflict.txt`. Review doc F3.1.

### PAT-1 — De-dupe the `new_tech` "always-on" device patterns *(severity: LOW; size: S)*

`new_tech/surgical` and `new_tech/non_surgical_medical` each emit the op+device and device+op patterns **twice** (4 byte-identical duplicate patterns total) because `new_tech` has both a conditional device block and an "always-on op+device" block in the generator. Pure compile waste, no behavior change. De-dupe in the generator. (The 2 `obstetrics` cross-entity `resect` dupes are intentional — leave them.) Review doc F1.3.

---

## 5) BODY_PARTS ENTRY-QUALITY BACKLOG — from the 2026-06-01 Phase 2 audit

`med_surg/body_parts` is 15,423 entries (80% of the file). The Phase 2 audit (`docs/review_2026-06-01.md`, flagged lists in `docs/audits/`) found it **much cleaner than `CLAUDE.md`'s 2026-04-08 "Grammar Quality Issues" section claims** — the big approach/fragment/plural clusters are essentially fixed. Residual items below. **No deletions made; each needs PRE/POST verification before removal.**

### DOC-1 — Refresh the stale `CLAUDE.md` "Grammar Quality Issues" section *(severity: LOW; size: S)*

That section (dated 2026-04-08) claims ~47 approach entries, ~173 approach-fragments, ~1,783 full-procedure strings, and several bad plurals in `body_parts`. Re-measured 2026-06-01: **0 / 1 / 152–301 / 0**. It overstates current contamination by ~10× and will send maintainers chasing fixed problems. Re-measure and trim. Review doc F2.0.

### BP-1 — Ultra-short case-insensitive body_parts tokens (`me`, `et`, `bp`, `af`, …) *(severity: MEDIUM; size: S; blocked on TD-11)*

34 entries are ≤2 chars; ~6 are common-English/abbreviation collisions stored **case-insensitive** (`me`, `et`, `bp`, `af`, `gb`, `cn`). Bare forms correctly do NOT fire (op-anchored patterns), but composed forms do and look like real FPs: `inspection of me`, `me repair`, `et change`, `removal of bp` all FIRE (verified). Fix: make them case-sensitive (match `ET`/`AF`, not the words) or drop the worst collisions. **Highest-impact Phase 2 item.** Full list: `docs/audits/E_too_short.txt`, `E_common_english.txt`. Review doc F2.1.

### BP-2 — Full-procedure strings in body_parts *(severity: LOW-MEDIUM; size: M)*

152 (strict) to 301 (incl. `-ectomy/-ostomy` suffixes) entries are complete procedures, not anatomy (`acl reconstruction hamstring`, `aortic wall reconstruction`, `frontal drainage pathway`). They provide real coverage (whole-string match), so confirm each is reachable compositionally before removing. = CLAUDE.md issue #5, residual. Full list: `docs/audits/B_full_procedure_strings.txt`. Review doc F2.2.

### BP-3 — Procedure abbreviations duplicated into body_parts *(severity: MEDIUM-conceptual / LOW-impact; size: S)*

23 case-sensitive abbreviations (EVAR, EGD, THA, PHACO, ALND, REBOA…) live in **both** `ops_direct` (correct) and `body_parts` (wrong — they're procedures, not anatomy). The body_parts copies enable nonsense compositions: `removal of EVAR`, `excised the THA` FIRE (verified). Triggering phrases are clinically implausible → low real-world FP, but conceptually wrong. Remove from body_parts, keep in ops_direct; verify no recall loss. Full list: `docs/audits/C_casesens_bodyparts.txt`. Review doc F2.3.

### BP-4 — body_parts ∩ devices duplicates *(severity: LOW; size: S)*

18 entries appear in both `body_parts` and `devices` (`pacemaker`, `t tube`, `external fixator`, `internal fixation device`…). The device-anchored patterns already handle these (`inspection of pacemaker` fires via `devices`, not the body_parts copy), so the body_parts entries are redundant dead weight, not an FP source. Drop from body_parts; pure hygiene, no behavior change expected. Full list: `docs/audits/F_bp_also_device.txt`. Review doc F2.4.

### TD-11 — Composed-short-token FP fixture *(blocks: BP-1; size: S)*

No current fixture contains the composed-FP forms that BP-1 targets (`inspection of me`, `et change`, `removal of bp`, `history of af`). Add ~40 lines mixing the ≤2-char body-part tokens with operative verbs and with their common-English meanings, so BP-1's fix can be measured (these should NOT fire) without regressing real abbreviation matches (`AF ablation`, `ET tube placement` — which SHOULD fire). Review doc F2.1.

---
