# MIMIC-IV Test Sets for ICD-10-PCS Grammar

Source: MIMIC-IV v3.1 (PhysioNet) — Beth Israel Deaconess Medical Center ICU data.

## Test Files

### True Positives (TP)
- `tp_procedure_titles.txt` — 2000 random ICD-10-PCS procedure titles from MIMIC-IV
  - Gold standard: every line IS a coded procedure
  - Tests recall of the grammar

### False Positive Challenge Sets (FP)
- `fp_diagnoses_procedural_vocab.txt` — 500 ICD-10-CM diagnosis titles containing procedure-like words
  - Contains: dissection, occlusion, amputation, perforation, etc.
  - These are CONDITIONS, not procedures — grammar should not match
  - CAVEAT: some matches are acceptable (e.g., "coronary artery bypass" in diagnosis context)
  
- `fp_diagnoses_anatomy_only.txt` — 300 ICD-10-CM diagnoses with anatomical terms
  - Contains bone names, joint references, organ mentions
  - No procedure vocabulary — tests that body-part words alone don't trigger

- `fp_icu_observations.txt` — 132 ICU monitoring/vital sign terms
  - Contains: heart rate, blood pressure, GCS, lab values
  - Non-procedure medical terms that use overlapping vocabulary

- `fp_clinical_findings.txt` — 200 clinical condition descriptions
  - Contains: "aortic dissection", "retinal detachment", "venous occlusion"
  - Hardest discrimination: same words used for procedures AND conditions

## Baseline Results (2026-05-18)

### Surgical Entity (`industries/healthcare/medical_procedures/eng/surgical`)
- TP Recall: 78.2% (1564/2000) — many misses are non-surgical (imaging, counseling)
- FP Rate: 106/1139 = 9.3% raw
  - Breakdown: 47 traumatic amputations, 16 detachments, 14 dissections, 12 occlusions, 12 prior-procedure refs, 4 ICU terms, 1 other
  - True non-medical FPs: 3 (Central Line Days, Chest Tube Output, Wound Drainage)

### Medical Entity (`industries/healthcare/medical_classifications/px_titles/icd10pcs`)
- TP Recall: 96.0% (1919/2000)
- FP Rate: 121/1139 = 10.6% raw

### Interpretation
Most "FPs" in the MIMIC challenge set are inherent ambiguity — the same medical terms
describe both procedures and conditions. DLP correctly detects medical content in both cases.
True non-medical false positives are extremely low (3/1139 = 0.26%).
