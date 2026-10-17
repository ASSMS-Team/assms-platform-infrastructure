# Quality-gate exit check

The Job Service analysis command returned exit code **2** when SonarQube rejected its quality gate. The build, 165 xUnit tests, coverage collection, scanner upload and background analysis all succeeded. This verifies that `-FailOnQualityGate` distinguishes a quality-policy failure from a failed build or test.

| Check | Temporary gate run | Restored gate run |
|---|---:|---:|
| Overall coverage | 44.3% | 44.3% |
| Gate result | ERROR | OK |
| Analysis result | Succeeded | Succeeded |
| Command exit code | 2 | 0 |

The temporary gate added a condition requiring at least 80% **overall** coverage. Job Service had 44.3%, so this condition failed. The 80% value was chosen only to exercise the exit path; it is not an agreed project-wide threshold. The normal Sonar way gate uses its own conditions and can report OK while overall coverage remains 44.3%. Review the coverage metric separately when interpreting that result.

The project again inherits the original default Sonar way gate. The temporary gate was deleted, and a fresh analysis returned OK. No source code was changed for this check.

Local evidence is in [the gate demonstration folder](.local/gate-demo-20261017T204417): `runner-exit-code.txt`, `analysis-console.txt`, `summary.json`, `temporary-gate-status.json`, `normal-run-summary.json`, `final-assignment.json` and `final-gate-status.json`. The gate-failure analysis is `20261017T204423044288`; the restored-gate analysis is `20261017T204613716140`. These generated files are excluded from Git because they belong to the local SonarQube instance.

To make a pipeline reject a failed gate, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-Analysis.ps1 -Project job -FailOnQualityGate
```

The command returns 0 when the analysis and gate pass, 1 for an analysis/setup failure, and 2 when analysis succeeds but the gate fails. It currently runs against local SonarQube. A hosted CI runner needs a reachable SonarQube server and its own credentials before this command can be used in GitHub Actions.
