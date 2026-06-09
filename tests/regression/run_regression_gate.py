#!/usr/bin/env python3
"""
run_regression_gate.py
======================
CI gate for the precision regression bucket.

Every line in `tests/regression/regressed_*.txt` (excluding blank lines and
lines starting with `#`) is a confirmed false positive that was previously
suppressed by a precision fix in the grammar. CI fails (exit 1) if any line
fires a match.

Bucket files are append-only. To remove a line, move it to
`tests/regression/retired/` with a rationale; never delete in place.

Usage
-----
    python3 tests/regression/run_regression_gate.py
    python3 tests/regression/run_regression_gate.py --no-compile
    python3 tests/regression/run_regression_gate.py --bucket tests/regression/regressed_2026_05_27.txt

Exit codes
----------
    0  no regressions (zero lines fired)
    1  one or more lines fired — print the offending lines and exit non-zero
    2  setup error (missing bucket file, compilation failure, etc.)
"""
import argparse
import glob
import os
import sys
import tempfile
from pathlib import Path

# Reuse helpers from the main test runner — single source of truth for
# edktool paths, compile logic, entity defaults, and match parsing.
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from v3_test_icd10pcs_strings import (
    DEFAULT_ENTITIES,
    DEFAULT_GRAMMAR,
    compile_grammar,
    run_file_batch,
)


def load_bucket(path):
    """Strip comments and blanks; return the remaining lines."""
    lines = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        lines.append(s)
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--bucket",
        action="append",
        dest="buckets",
        default=None,
        help=(
            "Bucket file to gate against (may repeat). "
            "Default: every tests/regression/regressed_*.txt."
        ),
    )
    parser.add_argument("--grammar", default=DEFAULT_GRAMMAR)
    parser.add_argument(
        "--no-compile",
        action="store_true",
        help="Skip compilation; reuse the existing .ecr.",
    )
    args = parser.parse_args()

    if args.buckets:
        bucket_paths = args.buckets
    else:
        repo_root = Path(__file__).parent.parent.parent
        bucket_paths = sorted(
            glob.glob(str(repo_root / "tests/regression/regressed_*.txt"))
        )

    if not bucket_paths:
        print("[ERROR] No bucket files found.", file=sys.stderr)
        return 2

    grammar_file = args.grammar
    ecr_file = grammar_file.replace(".xml", ".ecr")

    if args.no_compile:
        if not os.path.exists(ecr_file):
            print(f"[ERROR] --no-compile but {ecr_file} not found.", file=sys.stderr)
            return 2
    else:
        compile_grammar(grammar_file, ecr_file)

    print("=" * 65)
    print(f"REGRESSION GATE — {len(bucket_paths)} bucket file(s)")
    print("=" * 65)

    failures = []
    total_lines = 0
    with tempfile.TemporaryDirectory() as tmp_dir:
        for i, path in enumerate(bucket_paths):
            strings = load_bucket(path)
            total_lines += len(strings)
            if not strings:
                print(f"  {os.path.basename(path)}: (empty, skipped)")
                continue
            results = run_file_batch(ecr_file, strings, DEFAULT_ENTITIES, tmp_dir, offset=i * 10000)
            fired = [s for s, matched in results if matched]
            status = "PASS" if not fired else f"FAIL ({len(fired)} fired)"
            print(f"  {os.path.basename(path):<40}  {len(strings):>4} lines  {status}")
            for line in fired:
                failures.append((path, line))

    print("=" * 65)
    if failures:
        print(f"REGRESSION DETECTED — {len(failures)}/{total_lines} bucket line(s) fired:\n")
        for path, line in failures:
            print(f"  [{os.path.basename(path)}] {line}")
        print(
            "\nA precision fix has regressed. Investigate before merging:\n"
            "  - Was the fix's score=0 / blocklist accidentally removed?\n"
            "  - Did a new pattern open a longer-match path that survives suppression?\n"
            "  - If the regression is intentional (e.g., the line is no longer an FP),\n"
            "    move it to tests/regression/retired/ with a rationale.\n"
        )
        return 1

    print(f"OK — all {total_lines} regression-bucket lines correctly suppressed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
