# Job Service quality improvement

SonarQube reported that the job reference retry loop had no explicit stopping condition (`csharpsquid:S1994`). The loop relied on an exception filter to stop after three collisions. `InsertWithFreshReferenceAsync` now states the three-attempt limit in its loop condition. A final exception covers the otherwise unreachable path after the loop.

| Measure | Baseline | After change |
|---|---:|---:|
| Existing xUnit tests passed | 165 | 165 |
| SonarQube coverage | 44.4% | 44.4% |
| Open findings | 34 | 33 |
| Code smells | 33 | 32 |
| Estimated remediation effort | 224 minutes | 204 minutes |

The existing tests cover a collision followed by success, success on the third attempt, and an exception when all three attempts collide. The build, tests, coverage collection, scanner upload and SonarQube background task succeeded in the new run. The retry-loop finding is absent from the new issue list.

The remaining SQL construction finding (`csharpsquid:S2077`) has not been resolved or dismissed. In `JobRepository.ListAsync`, the SQL predicate text is chosen from fixed strings and filter values are passed as command parameters. Its risk and an appropriate scanner resolution still require review.

The quality gate reports `OK`, but this does not mean overall coverage meets the gate's new-code threshold. The new run reports 50.0% new-code coverage, while overall Job Service coverage remains 44.4%. Keep these measures distinct in the presentation.

Evidence: [baseline](BASELINE.md), [changed source](../../../assms-job-service/src/JobService/Services/JobService.cs), [new run summary](.local/analysis-runs/20261017T194723840341/summary.json), [new test and scanner artifacts](../../../assms-job-service/quality/artifacts/20261017T194723840341/), and [local SonarQube screenshot](.local/job-service-after.png). The baseline run ID is `20261017T182212432163`; the new run ID is `20261017T194723840341`.
