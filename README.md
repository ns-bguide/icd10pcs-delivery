# ICD-10-PCS Medical Procedures — Delivery Package

Self-contained bundle of the ICD-10-PCS DLP grammar + its test data.
Prepared by Bruno Guide (ENG-772528), 2026-06-09.

## Contents

```
grammar/
  ns_ecr_industries-healthcare-icd10pcs_procedures.xml   ← the grammar (compile this)
  ns_ecr_industries-healthcare-medical_conditions.xml    ← include (referenced by the grammar)
common/
  ns_blocks-chars.xml                                    ← include (referenced by medical_conditions)
benchmark/
  Procedure_Name_Master_List_MERGED_clean.txt            ← 34,928 R&D-curated procedures (TP benchmark)
  Procedure_Name_Master_List_MERGED_ambiguous.txt        ← ambiguous set (excluded from headline)
tests/                                                   ← full test corpus (see tests/README.md)
  true_positives/      should-match fixtures
  false_positives/     should-NOT-match fixtures (curated FP families)
  mimic_iv/            real de-identified ICU text (2,000 TP titles + FP challenge sets)
  regression/          confirmed-fixed FPs + CI gate (must stay green)
```

The directory layout matters: `medical_conditions.xml` includes `../common/...`, so the
grammar must be compiled from `grammar/` with `common/` as its sibling (as shipped).

## Two public entities (surgical ⊆ medical)

- `industries/healthcare/medical_procedures/eng/surgical` — surgical procedures (David, ENG-772518)
- `industries/healthcare/medical_classifications/px_titles/icd10pcs` — medical superset (Bruno, ENG-772528)

## Compile

Toolchain: **edktool v10.9.0** (production parity — a v25.4.0-compiled `.ecr` will NOT load in it).

```bash
cd grammar/
EDK=<path>/3p/v10.9.0/bin/edktool.exe
LIC=<path>/3p/v10.9.0/lic/licensekey.dat
$EDK compile -i ns_ecr_industries-healthcare-icd10pcs_procedures.xml -l $LIC \
     -o ns_ecr_industries-healthcare-icd10pcs_procedures.ecr
# ~47s; produces ~9.4 MB .ecr
```

## Test (extract against a fixture)

```bash
ENT=industries/healthcare/medical_classifications/px_titles/icd10pcs   # or .../eng/surgical
$EDK extract -l $LIC -g grammar/...procedures.ecr \
     -i benchmark/Procedure_Name_Master_List_MERGED_clean.txt \
     -o results.xml -e "$ENT" -q
# results.xml lists each match: offset + NORMALIZED_TEXT. A line with >=1 MATCH "fired".
```
Recall = fired lines / total lines (TP fixtures). FP rate = fired lines / total (FP fixtures).

## Current quality (medical entity, v10.9.0, 2026-06-09)

| Gate | Result |
|---|---:|
| Madeleine MERGED_clean recall | 92.89% |
| tier1_canonical recall | 98.51% |
| MIMIC TP recall (medical / surgical) | 97.6% / 79.3% |
| MIMIC FP (medical / surgical) | 2.55% / 1.23% |
| Regression gate (158 lines) | PASS |

## Notes

- **Policy: include-historical** — the entity matches historical/status-post procedures
  ("history of appendectomy") because they're still PHI for DLP. Those live in
  `tests/true_positives/medical_historical_procedures.txt`, not the FP set.
- The grammar is **generated** (from CMS tables + curated lists); this package ships the
  generated XML, not the generator. For provenance/regeneration see the source repo
  branch `bguide/eng-772528-medical-classifications`.
- `tests/README.md` maps every fixture file in detail.
