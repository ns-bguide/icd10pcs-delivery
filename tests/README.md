# ICD-10-PCS test data — index

Guide to the test corpus for the ICD-10-PCS DLP grammar. **Everything here is
git-tracked** — if you're on the repo (`bguide/eng-772528-medical-classifications`
or `integration`), you already have all of it; just `git pull`. Paths below are
relative to the repo root.

Two public entities are evaluated against this data:
- `industries/healthcare/medical_procedures/eng/surgical` — surgical (David / ENG-772518)
- `industries/healthcare/medical_classifications/px_titles/icd10pcs` — medical superset (Bruno / ENG-772528)

Surgical ⊆ medical. Line counts below are non-blank lines as of 2026-06-09.

---

## How to run the data against the grammar

```bash
# headline benchmark (recall on TP fixtures + FP fixtures), reuse existing .ecr:
python3 v3_benchmark.py --no-compile
# or compile first (v10.9.0 is the canonical toolchain — production parity):
python3 v3_benchmark.py

# ad-hoc: test an arbitrary list of strings
python3 v3_test_icd10pcs_strings.py --strings myfile.txt --no-compile

# regression gate (must exit 0 — no previously-fixed FP may re-fire)
python3 tests/regression/run_regression_gate.py
```

The benchmark resolves entities for both surgical and medical, so you can see
each side. `data/madeleine/Procedure_Name_Master_List_MERGED_clean.txt` (34,928
lines) is the headline recall benchmark.

---

## True positives — strings that SHOULD match

### Quality tiers (curated, cleanest → noisiest)
| File | Lines | Content |
|---|---:|---|
| `tier1_canonical.txt` | 1,071 | CMS canonical procedure titles |
| `tier2_common.txt` | 2,252 | Common-name forms (e.g. "laparoscopic appendectomy") |
| `tier3_clinical.txt` | 5,091 | Clinical variants |
| `tier3_clinical_extra.txt` | 8 | Procedures rescued from FP files (FP-5 cleanup) |
| `tier4_shorthand.txt` | 4,322 | Clinical shorthand |
| `tier5_billing.txt` | 2,669 | Billing/EHR shorthand |
| `tier6_abbreviation.txt` | 3,289 | Pure abbreviation forms (CABG, EVAR, …) |

### Curated composites (pre-merged tier subsets used as benchmark cuts)
| File | Lines | Content |
|---|---:|---|
| `tier1_2_high_quality.txt` | 3,323 | tiers 1+2 |
| `tier1_2_high_quality_high_confidence.txt` | 2,777 | high-confidence subset |
| `tier1_2_3_production.txt` | 5,388 | tiers 1+2+3, production cut |
| `tier1_2_with_sentences.txt` | 500 | + full-sentence embeddings |
| `tier1_2_3_high_conf_with_sentences.txt` | 1,000 | + sentences, high-conf |

### `true_positives/` (newer, scope-tagged per the collaboration convention)
| File | Lines | Content |
|---|---:|---|
| `true_positives/tier_short_abbrev_should_match.txt` | 7 | short cardiac/anatomic abbrevs that SHOULD fire (AV/MV/TV node…) — BP-1 guardrail |
| `true_positives/rec3_op_device_into_bp.txt` | 54 | `<op> of <device> <prep> <bp>` forms (REC-3) |

---

## False positives — strings that should NOT match

### `false_positives/` (curated, grouped by FP type)
| File | Lines | What it guards |
|---|---:|---|
| `false_positives_all.txt` | 785 | umbrella master FP list |
| `fp_status_descriptions.txt` | 29 | "history of appendectomy", status-post (FP-1) |
| `fp_diagnostic_phrases.txt` | 299 | diagnoses sharing words with procedures |
| `fp_diagnoses.txt` | 83 | pure diagnosis names |
| `fp_anatomy_only.txt` | 66 | bare anatomy, no operation |
| `fp_clinical_findings.txt` | 49 | findings/observations/labs |
| `fp_clinical_terms_not_procedures.txt` | 46 | clinical jargon that isn't a procedure |
| `fp_confusable_general.txt` | 46 | common-English collisions |
| `fp_confusable_words.txt` | 31 | confusable medical words |
| `fp_equipment_supplies.txt` | 34 | bare equipment ("chest tube") (FP-3) |
| `fp_imaging_diagnostic.txt` | 36 | "CT scan", "ultrasound" |
| `fp_medication_administration.txt` | 24 | drug administration |
| `fp_roles_specialties.txt` | 31 | "cardiologist", "surgical resident" |
| `fp_ophthalmic_diagnoses.txt` | 42 | retinal/choroidal detachment etc. (FP-4) |
| `fp_vessel_pathology.txt` | 57 | vessel dissection/occlusion diagnoses (FP-2.a) |
| `fp_traumatic_amputation.txt` | 61 | "traumatic amputation of …" diagnoses (FP-2.b) |
| `fp_composed_short_tokens.txt` | 23 | composed short-token FPs ("inspection of me") (BP-1/TD-11) |
| `fp_rec3_control.txt` | 14 | REC-3 widening control |
| `compositional_fp_risk.txt` | 96 | tricky common-English compositions |
| `sentences_false_positive.txt` | 197 | full sentences that should not fire |
| `MIGRATION_2026-05-25.md` | — | doc: FP-5 mislabel cleanup record |

---

## MIMIC-IV — real de-identified ICU clinical text (`mimic_iv/`)
The "does it work on actual hospital text" benchmark. See `mimic_iv/README.md`.
| File | Lines | Role |
|---|---:|---|
| `tp_procedure_titles.txt` | 2,000 | real procedure titles — SHOULD match |
| `fp_diagnoses_procedural_vocab.txt` | 500 | diagnoses with procedure roots — should NOT |
| `fp_diagnoses_anatomy_only.txt` | 300 | bare-anatomy diagnoses |
| `fp_clinical_findings.txt` | 204 | findings/observations |
| `fp_icu_observations.txt` | 135 | ICU monitoring entries |

---

## Regression bucket (`regression/`)
Every confirmed FP that a precision fix eliminated lives here; the gate fails CI
if any line re-fires. Run on every grammar-logic change.
| File | Lines | Content |
|---|---:|---|
| `regressed_2026_05_27.txt` | 101 | FP-3 + FP-4 v1 + FP-2.b wins |
| `regressed_2026_05_28.txt` | 57 | FP-2.a + FP-4 v2 wins |
| `run_regression_gate.py` | — | the gate (exit non-zero if any line fires) |

---

## Generated test families (produced by `v2_cms.py` from the CMS tables)
These are auto-generated synthetic strings per ICD-10-PCS section, not hand-curated.
Regenerable; useful for broad coverage probing, noisy by nature.
- `v2_noun_compounds_<section>.txt` (17 files) — noun-compound forms per section
- `v2_sentences_<section>.txt` (12) — full-sentence embeddings
- `v2_verbal_<section>.txt` (10) — verbal/verb-phrase forms
- `v2_components_*.txt` (10) — per-axis component lists (body_parts, devices, approaches, operations, qualifiers; + `_extended`)
- `v2_titles_short.txt`, `v2_alt_struct_X.txt` — title/alt-structure forms
- `v2_ollama_should_match.txt` / `v2_ollama_should_not_match.txt` / `v2_ollama_ambiguous.txt` — LLM-generated positive/negative/ambiguous probes

> Section codes: 0=Med-Surg, 1=Obstetrics, 2=Placement, 3=Administration,
> 4=Meas/Mon, 5/6=Extracorporeal, 7=Osteopathic, 8=Other, 9=Chiropractic,
> B=Imaging, C=Nuclear, D=Radiation, F=Rehab, G=Mental Health, H=Substance, X=New Tech.

---

## Madeleine master lists (under `data/madeleine/`, not `tests/`)
The headline positive benchmark sets.
| File | Role |
|---|---|
| `Procedure_Name_Master_List.txt` | 30k procedure strings (base positive set) |
| `Procedure_Name_Master_List_MERGED_clean.txt` | 34,928 — **the headline recall benchmark** |
| `Procedure_Name_Master_List_MERGED_ambiguous.txt` | ambiguous set (excluded from headline) |
| `*_misses.txt` | benchmark OUTPUT (gitignored, regenerated each run) — not input data |

---

## Naming convention for NEW fixtures (per CLAUDE.md)
- `tests/true_positives/surgical_*.txt` — David's authority (match surgical entity)
- `tests/true_positives/medical_*.txt` — Bruno's authority (match medical, not surgical)
- `tests/true_positives/mixed_*.txt` — overlap (covered by both)
- Same pattern under `tests/false_positives/`.
Existing tier/fp files are shared and not retro-split.
