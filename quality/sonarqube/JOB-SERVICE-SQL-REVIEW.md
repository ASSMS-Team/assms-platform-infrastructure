# Job Service SQL query review

`JobRepository.ListAsync` accepts optional status and assigned technician filters. The previous implementation assembled the SQL predicate list at runtime, which SonarQube reported under `csharpsquid:S2077`. The filter values were already bound through `MySqlCommand.Parameters`; review found no user value inserted into the SQL text.

The repository now selects one of four constant queries: no filter, status only, technician only, or both filters. Each query keeps the same `ORDER BY created_at DESC, job_reference ASC` and uses the same named parameters as before. The SQL text no longer depends on a runtime predicate list.

| Measure | After retry-loop change | After SQL change |
|---|---:|---:|
| Existing xUnit tests passed | 165 | 165 |
| Open SonarQube findings | 33 | 32 |
| Reported vulnerabilities | 1 | 0 |
| SonarQube coverage | 44.4% | 44.3% |

The new scan succeeded and the `S2077` finding is absent. This result shows that the static analyzer accepts the revised query construction; it is not a complete security assessment. The existing xUnit tests exercise controller and service behavior through a fake repository, so they do not verify these four queries against MySQL. A disposable database integration check is still needed before claiming runtime verification of this repository method.

Evidence: [changed repository](../../../assms-job-service/src/JobService/Repositories/JobRepository.cs), [preceding improvement](JOB-SERVICE-IMPROVEMENT.md), [new run summary](.local/analysis-runs/20261017T203215842092/summary.json), and [test and scanner artifacts](../../../assms-job-service/quality/artifacts/20261017T203215842092/). The preceding run ID is `20261017T194723840341`; the new run ID is `20261017T203215842092`.
