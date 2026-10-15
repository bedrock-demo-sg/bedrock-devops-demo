# Deliberate failing finding (demo asset)

`ClientReviewSearch.cls` builds dynamic SOQL by concatenating a parameter (SOQL injection) and runs it with `Database.query`.

To demo: on a branch, copy `ClientReviewSearch.cls` and `ClientReviewSearch.cls-meta.xml` into `force-app/main/default/classes/`, open a PR. Never merge to main.

Command (same as CI):
`sf code-analyzer run --config-file code-analyzer.yml --target force-app --severity-threshold 2`

Verified result (Code Analyzer v5.11.0, 2026-10-15): FAILS, exit code 2.

| Severity | Engine | Rule | Location |
|---|---|---|---|
| 2 (High) | pmd | ApexSOQLInjection | ClientReviewSearch.cls:6:31, "Avoid untrusted/unescaped variables in DML query" |
| 4 (Low) | pmd | ApexDoc | two missing-doc findings (below threshold) |

Output ends with: `Error (ThresholdExceeded): 1 violations met or exceeded the severity threshold of "High".`

Alternative that also fails reliably: any query or DML without user mode (`[SELECT Id FROM Client_Review__c]`, `insert x;`) gives `pmd:ApexCRUDViolation`, severity 2 (High), one finding per statement.

Clean main scan for comparison: 7 findings, all severity 3-4, exit 0.

Fix: `Database.query(soql, AccessLevel.USER_MODE)` with a bind variable (`WHERE Risk_Profile__c = :riskProfile`) instead of concatenation.
