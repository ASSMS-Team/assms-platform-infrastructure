# ASE code quality baseline

Fresh local coverage and SonarQube analyses were completed for the four backend services and frontend. Application code and existing test assertions were unchanged.

| Repository | Tests passed | Skipped | Sonar coverage | Duplication | Open issues | Estimated debt (minutes) |
|---|---:|---:|---:|---:|---:|---:|
| assms-job-service | 165 | 0 | 44.4% | 3.9% | 34 | 224 |
| assms-customer-asset-service | 152 | 0 | 40.5% | 8.4% | 29 | 144 |
| assms-dispatch-service | 116 | 11 | 37.7% | 5.2% | 21 | 60 |
| assms-reporting-service | 96 | 0 | 52.8% | 5.7% | 19 | 84 |
| assms-frontend | 91 | 0 | 43.6% | 4.3% | 234 | 1658 |

Latest successful test executions: **620 passed, 0 failed, 11 skipped**. Repeated attempts are not added to these counts.

Dispatch database integration tests remain skipped because this run supplies no disposable test-database connection. They are not counted as passed.

The coverage column is SonarQube's combined line and condition metric. Line and branch coverage are recorded separately in the raw metrics. Coverage includes untested production code; test assemblies and frontend test/setup files are excluded from its denominator.

Open issues counts unique findings. The dashboard uses MQR mode, where one finding can affect several quality categories. Its Security, Reliability and Maintainability counts must not be added to obtain a unique issue total. Estimated debt in this table uses the `sqale_index` metric.

All five projects returned Sonar way status `OK` with zero evaluated new-code conditions on this first analysis. This does not establish overall coverage acceptance or resolve the reported findings.

Open issues and estimated remediation effort are tool outputs. Review findings before classifying them as confirmed defects or selecting changes. No findings were suppressed or marked resolved by this run.

The frontend scanner completed with a nonfatal diagnostic from `jsx-ast-utils`: it could not resolve a prop expression of type `MetaProperty`. The original message is retained in the frontend scanner log. Analysis and coverage import completed, but conclusions about affected JSX prop checks require follow-up.

## Analysis evidence

These results come from separate analysis runs. The source revision and exact run record for each project are:

| Repository | Source revision | Run ID |
|---|---|---|
| assms-job-service | `aac7c87507e0728d2f3d4d50908d702fbe257699` | `20261017T182212432163` |
| assms-customer-asset-service | `13e8b5dd9fe81fbf4a25d6755cda2786bb00856e` | `20261017T182530737546` |
| assms-dispatch-service | `0585f70779e6e6955b2a0739f7a8c4683216a12f` | `20261017T182530737546` |
| assms-reporting-service | `7d50b2f134dbbfa2564578769e0d7183a5ab2554` | `20261017T182530737546` |
| assms-frontend | `821c2b301cdf56558ec1e265c9523468673dbf74` | `20261017T183854106727` |

Each repository retains its logs, test results, coverage reports, background-task result and quality-gate response in `quality/artifacts/<run-id>/`. The aggregate source record is `.local/baseline-summary.json`; it includes uncommitted analysis-configuration changes and references the original run summaries.

Open [the local SonarQube projects](http://localhost:9000/projects) to inspect individual findings. Use [the run guide](README.md#run-coverage-and-analysis) to repeat the measurements.
