# Job Service MySQL filter check

The revised `JobRepository.ListAsync` ran against an isolated MySQL 8.0.40 container. The check applied the Job Service migrations V01 through V07, inserted four synthetic jobs, and exercised the repository through `MySqlConnectionFactory`.

| Repository call | Expected jobs | Result |
|---|---:|---|
| No filters | 4 | Pass |
| Status only | 2 | Pass |
| Technician only | 2 | Pass |
| Status and technician | 1 | Pass |
| SQL-looking status value | 0 | Pass |
| SQL-looking technician value | 0 | Pass |
| All rows after the reads | 4 | Pass |

The check used a new database and removed its container after execution. It did not connect to the existing ASSMS MySQL container. The SQL-looking values did not expand the result set or change the synthetic rows. These results verify the tested query cases; they do not establish performance or a complete security assessment.

Run the check from the Job Service repository with Docker Desktop running:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\quality\integration\Run-JobListCheck.ps1
```

The script creates a random temporary database password and a container with a loopback-only, automatically assigned port. It applies the repository's migrations, runs the [integration program](../../../assms-job-service/quality/integration/Program.cs), saves the assertions, and removes the container. The seven assertions are separate from the 165 existing xUnit tests and are not included in SonarQube coverage.

Evidence: [result log](../../../assms-job-service/quality/artifacts/job-list-20261017T203918914/results.txt), [runner](../../../assms-job-service/quality/integration/Run-JobListCheck.ps1), and [SQL review](JOB-SERVICE-SQL-REVIEW.md). Docker's container list showed no remaining `assms-ase-job-list-` container after the run.
