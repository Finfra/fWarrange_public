#!/usr/bin/env python3
"""Judge apiTestDo.sh / cmdTestDo.sh output per test, by response content (Issue114).

Usage: bash apiTestDo.sh all 2>&1 | python3 fwc-verdict.py [label]

The runners print each test as:
    ========================================
    [NN] name
    ========================================
    <output>

Rules
* Normal test (NN is numeric)
    - SKIP if the output starts with "SKIP:"
    - FAIL on any failure marker (error status, jq/curl error, CLI error, empty output)
    - FAIL if no success marker ("status": "ok" or a bare "ok" line from `jq .status`)
    - otherwise PASS
* Error test (NN starts with E)
    - FAIL if the output carries a success status or is empty
    - PASS if it carries an error marker (error status, CLI error line, non-zero exit code)
    - otherwise FAIL

Prints one line per non-passing test and a summary line; exit code 1 if any FAIL.
"""
import re
import sys

HEADER = re.compile(r"^=+\n\[([^\]]+)\] ([^\n]*)\n=+\n", re.M)
OK_STATUS = re.compile(r'"status"\s*:\s*"ok"|^"ok"$', re.M)
ERR_STATUS = re.compile(r'"status"\s*:\s*"error"', re.M)
FAIL_MARKERS = re.compile(
    r'"status"\s*:\s*"error"'      # API error envelope
    r"|^jq: error"                 # broken jq filter / unexpected shape
    r"|^parse error"               # non-JSON response piped to jq
    r"|^curl: \(\d+\)"             # transport failure
    r"|^오류:"                      # CLI error line
    r"|^exit code: [1-9]",         # CLI non-zero exit
    re.M,
)
ERR_MARKERS = re.compile(r'"status"\s*:\s*"error"|^오류:|^exit code: [1-9]', re.M)
# Section dividers printed by the runners between groups
DIVIDER = re.compile(r"^={4,} .* ={4,}$", re.M)


def judge(num, body):
    text = DIVIDER.split(body)[0].strip()
    if num[:1].upper() == "E":
        if not text:
            return "FAIL", "empty output"
        if OK_STATUS.search(text):
            return "FAIL", "error test returned success"
        if ERR_MARKERS.search(text):
            return "PASS", ""
        return "FAIL", "no error marker"
    if text.startswith("SKIP:"):
        return "SKIP", text.splitlines()[0]
    if not text:
        return "FAIL", "empty output"
    m = FAIL_MARKERS.search(text)
    if m:
        return "FAIL", m.group(0)
    if not OK_STATUS.search(text):
        return "FAIL", "no success marker"
    return "PASS", ""


def main():
    label = sys.argv[1] if len(sys.argv) > 1 else "tests"
    data = sys.stdin.read()
    heads = list(HEADER.finditer(data))
    counts = {"PASS": 0, "FAIL": 0, "SKIP": 0}
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(data)
        verdict, why = judge(h.group(1), data[h.end():end])
        counts[verdict] += 1
        if verdict != "PASS":
            print(f"  {verdict} [{h.group(1)}] {h.group(2)} — {why}")
    total = sum(counts.values())
    print(f"{label}: total={total} pass={counts['PASS']} fail={counts['FAIL']} skip={counts['SKIP']}")
    sys.exit(1 if counts["FAIL"] or total == 0 else 0)


if __name__ == "__main__":
    main()
