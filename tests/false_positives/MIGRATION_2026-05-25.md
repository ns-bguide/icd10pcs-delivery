# FP fixture migration — 2026-05-25 (FP-5)

Tracked in `tests/BACKLOG.md` as **FP-5: True-positive mislabeling cleanup**.

The earlier FP fixtures included several lines that are *legitimate procedure mentions* — keeping them in `false_positives/` distorts the FP gradient and would cause FP-1/FP-2 to regress them when those items ship.

## Lines moved out of FP fixtures into TP corpus

| Removed from | Line | Destination |
|---|---|---|
| `false_positives_all.txt`, `fp_clinical_terms_not_procedures.txt`, `sentences_false_positive.txt` | `central line placement` | already in `tier4_shorthand.txt` and `madeleine_clean.txt` (deleted from FP only) |
| `false_positives_all.txt`, `fp_imaging_diagnostic.txt` | `ct guided biopsy` | `tier3_clinical_extra.txt` |
| `false_positives_all.txt`, `fp_confusable_words.txt` | `drainage of abscess` | `tier3_clinical_extra.txt` |
| `false_positives_all.txt`, `fp_confusable_words.txt` | `excision of lesion` | `tier3_clinical_extra.txt` |
| `false_positives_all.txt`, `fp_medication_administration.txt` | `bone marrow aspiration for pathology` | `tier3_clinical_extra.txt` |
| `false_positives_all.txt`, `fp_medication_administration.txt` | `joint aspiration for analysis` | `tier3_clinical_extra.txt` |
| `false_positives_all.txt`, `fp_medication_administration.txt` | `nerve block with local anesthetic` | `tier3_clinical_extra.txt` |
| `false_positives_all.txt`, `fp_medication_administration.txt` | `paracentesis for fluid analysis` | `tier3_clinical_extra.txt` |
| `false_positives_all.txt`, `fp_medication_administration.txt` | `thoracentesis for diagnostic purposes` | `tier3_clinical_extra.txt` |

## Sentence-form lines moved

| Removed from | Line | Destination |
|---|---|---|
| `sentences_false_positive.txt` | `Post central line placement, patient recovering well.` | (genuine procedure mention — kept as TP context, not migrated to fixture; covered by tier3 entry) |
| `sentences_false_positive.txt` | `The open reduction was performed without complications.` | (genuine procedure — bare form already in `tier4_shorthand.txt`/`madeleine_clean.txt`) |

For the two sentence-form rescues we **delete** rather than migrate to `sentences_true_positive.txt` because both contain procedure phrasing that is already separately covered by their bare-form entries. Adding a sentence wrapper does not give us new coverage.

## Lines NOT moved (kept as legitimate FPs)

These remain in `false_positives/` and are addressed by upcoming backlog items rather than data hygiene:

- **Anatomy + dissection/occlusion/detachment** (e.g., `aortic dissection`, `retinal detachment`, `celiac occlusion`) — addressed by FP-2 (procedure-word-in-diagnosis disambiguation) and FP-4 (retinal cluster).
- **Status-framed procedure mentions** (e.g., `history of appendectomy`, `status post knee arthroplasty`, `prior cholecystectomy`) — addressed by FP-1 (historical context guard). These are FPs *only if R&D confirms the entity is active-only scope*; they remain in the fixture so we can measure FP-1's impact.
- **Equipment without an operative verb** (e.g., bare `arterial line`, bare `chest tube`) — addressed by FP-3 (equipment-only standalone removal).
- **Common-English collisions in `compositional_fp_risk.txt`** (e.g., "the surgeon resected the paragraph from the manuscript") — these are correctly negative.
- **Pathology framings** (e.g., `excision margin positive`, `excision site healing well`, `resection margin clear`) — pathology-report context where excision/resection refer to the *result* of a prior procedure, not a current order.
- **`aortic root dilation`, `detachment of the retina`, `fragmentation of the kidney stone noted on imaging`** — diagnostic descriptions, addressed by FP-2/FP-4.

## Measured impact

Before migration: 119 FP-fixture firings out of 2,022 lines = 5.9% line-level FP.

After migration (measured 2026-05-25): **98 firings out of 1,879 lines = 5.2% line-level FP**.

| File | Before | After |
|---|---:|---:|
| `false_positives_all.txt` | 55/795 = 6.9% | 46/786 = 5.9% |
| `fp_clinical_terms_not_procedures.txt` | 2/48 = 4.2% | 1/47 = 2.1% |
| `fp_confusable_words.txt` | 3/35 = 8.6% | 0/32 = 0.0% |
| `fp_imaging_diagnostic.txt` | 1/38 = 2.6% | 0/37 = 0.0% |
| `fp_medication_administration.txt` | 5/30 = 16.7% | 0/25 = 0.0% |
| `sentences_false_positive.txt` | 6/200 = 3.0% | 4/198 = 2.0% |
| **TOTAL** | **119/2022 = 5.9%** | **98/1879 = 5.2%** |

The *underlying* grammar precision is unchanged — we corrected a mislabeling, not the model. The cleaner gradient lets FP-1/FP-2/FP-3 report honest impact numbers.

All 8 rescued procedures match correctly in the new `tier3_clinical_extra.txt`, confirming they were genuine TPs all along.

---

## FP fixture migration — 2026-06-09 (FP→TP, surgical scope)

Decision by David (surgical entity owner, ENG-772518): 5 organ
dissection/occlusion/perforation terms are within scope of
`industries/healthcare/medical_procedures/eng/surgical` and should match.

| Removed from | Line | Destination |
|---|---|---|
| `false_positives_all.txt`, `fp_diagnostic_phrases.txt` | `gastric dissection` | `tests/true_positives/surgical_dissection_occlusion.txt` |
| `false_positives_all.txt`, `fp_diagnostic_phrases.txt` | `pancreatic dissection` | same |
| `false_positives_all.txt`, `fp_diagnostic_phrases.txt` | `urethral dissection` | same |
| `false_positives_all.txt`, `fp_diagnostic_phrases.txt` | `ureteral occlusion` | same |
| `false_positives_all.txt`, `fp_diagnostic_phrases.txt` | `tibial perforation` | same — **currently a MISS (recall gap), tracked as failing TP** |

Notes: 4 of 5 already fire against both entities (surgical ⊆ medical); `tibial
perforation` does not yet match. None were in `fp_vessel_pathology.txt`, so this
does not conflict with the FP-2.a vessel-pathology suppression. No regression-bucket
conflict.
