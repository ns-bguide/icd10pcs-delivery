#!/bin/bash
# Run MIMIC-IV benchmarks against the ICD-10-PCS grammar
# Usage: ./run_mimic_benchmarks.sh [path_to_ecr]

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ECR="${1:-$REPO_ROOT/ns_ecr_industries-healthcare-icd10pcs_procedures.ecr}"
EDKTOOL="/home/bguide/git_root/dlp-ci-content/EductionSDK/3p/v25.4.0/bin/edktool.exe"
LICENSE="/home/bguide/git_root/dlp-ci-content/EductionSDK/3p/v25.4.0/lic/licensekey.dat"
TESTDIR="$REPO_ROOT/tests/mimic_iv"
OUTDIR="${MIMIC_OUT:-/tmp/mimic_benchmarks}"

mkdir -p "$OUTDIR"

echo "=== MIMIC-IV Grammar Benchmark ==="
echo "ECR: $ECR"
echo ""

# TP: Surgical entity
echo "--- TP: Surgical Entity ---"
$EDKTOOL extract -l "$LICENSE" -g "$ECR" \
  -e "industries/healthcare/medical_procedures/eng/surgical" \
  -i "$TESTDIR/tp_procedure_titles.txt" \
  -o "$OUTDIR/tp_surgical.xml" 2>/dev/null

# TP: Medical entity  
echo "--- TP: Medical Entity ---"
$EDKTOOL extract -l "$LICENSE" -g "$ECR" \
  -e "industries/healthcare/medical_classifications/px_titles/icd10pcs" \
  -i "$TESTDIR/tp_procedure_titles.txt" \
  -o "$OUTDIR/tp_medical.xml" 2>/dev/null

# FP: Combined challenge set
cat "$TESTDIR/fp_diagnoses_procedural_vocab.txt" \
    "$TESTDIR/fp_diagnoses_anatomy_only.txt" \
    <(grep -v '^#' "$TESTDIR/fp_icu_observations.txt" | grep -v '^$') \
    <(grep -v '^#' "$TESTDIR/fp_clinical_findings.txt" | grep -v '^$') \
    > "$OUTDIR/fp_combined.txt"

echo "--- FP: Surgical Entity ---"
$EDKTOOL extract -l "$LICENSE" -g "$ECR" \
  -e "industries/healthcare/medical_procedures/eng/surgical" \
  -i "$OUTDIR/fp_combined.txt" \
  -o "$OUTDIR/fp_surgical.xml" 2>/dev/null

echo "--- FP: Medical Entity ---"
$EDKTOOL extract -l "$LICENSE" -g "$ECR" \
  -e "industries/healthcare/medical_classifications/px_titles/icd10pcs" \
  -i "$OUTDIR/fp_combined.txt" \
  -o "$OUTDIR/fp_medical.xml" 2>/dev/null

# Parse results
TESTDIR="$TESTDIR" MIMIC_OUT="$OUTDIR" python3 << 'PYEOF'
import xml.etree.ElementTree as ET
import os

outdir = os.environ.get("MIMIC_OUT", "/tmp/mimic_benchmarks")
testdir = os.environ["TESTDIR"]

def count_matched_lines(xml_file, input_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()
    matches = root.findall('.//MATCH')
    
    with open(input_file, "rb") as f:
        content = f.read()
    lines = [l for l in content.split(b'\n') if l.strip()]
    total = len(lines)
    
    line_offsets = []
    pos = 0
    for line in content.split(b'\n'):
        line_offsets.append(pos)
        pos += len(line) + 1
    
    matched = set()
    for m in matches:
        offset = int(m.get('Offset', '0'))
        for i in range(len(line_offsets) - 1):
            if line_offsets[i] <= offset < line_offsets[i+1]:
                matched.add(i)
                break
    
    return len(matched), total, len(matches)

def count_fp_matches(xml_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()
    matches = root.findall('.//MATCH')
    unique = set()
    for m in matches:
        orig = m.find('ORIGINAL_TEXT')
        if orig is not None:
            unique.add(orig.text)
    return len(matches), len(unique)

print("\n" + "="*60)
print("MIMIC-IV BENCHMARK RESULTS")
print("="*60)

# TP
tp_file = f"{testdir}/tp_procedure_titles.txt"
for entity, label in [("surgical", "Surgical"), ("medical", "Medical (superset)")]:
    matched, total, raw = count_matched_lines(f"{outdir}/tp_{entity}.xml", tp_file)
    print(f"\n  {label} Entity - TP Recall:")
    print(f"    Lines matched: {matched}/{total} ({matched/total*100:.1f}%)")
    print(f"    Raw matches: {raw}")

# FP
fp_file = f"{outdir}/fp_combined.txt"
with open(fp_file) as f:
    fp_total = sum(1 for l in f if l.strip())

for entity, label in [("surgical", "Surgical"), ("medical", "Medical (superset)")]:
    raw, unique = count_fp_matches(f"{outdir}/fp_{entity}.xml")
    print(f"\n  {label} Entity - FP Rate:")
    print(f"    Matches: {raw} ({unique} unique terms)")
    print(f"    FP rate: {unique}/{fp_total} = {unique/fp_total*100:.1f}%")

print("\n" + "="*60)
PYEOF
