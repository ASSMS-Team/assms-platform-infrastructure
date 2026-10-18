# Local SonarQube for ASE

Run SonarQube at **http://localhost:9000** using Docker Desktop's Linux engine. This setup creates a separate PostgreSQL database and five private analysis projects, one for each ASSMS service repository and the frontend.

## Start and sign in

Open Docker Desktop and wait for the engine to run. In PowerShell:

```powershell
Set-Location 'F:\Projects\ASSMS\assms-platform-infrastructure\quality\sonarqube'
powershell -NoProfile -ExecutionPolicy Bypass -File .\Start-SonarQube.ps1
```

The script validates Compose, starts the containers, waits for the server to report `UP`, and initializes the administrator account and projects. First startup downloads the images if they are missing and initializes the database.

Open http://localhost:9000. The username and generated password are in [the private local credentials file](.local/admin-credentials.json). The initializer replaces the default administrator password. Keep this file private; it is excluded from Git.

## What runs

| Component | Purpose |
|---|---|
| SonarQube Community Build `26.10.0.133078` | Receives analysis reports and displays findings and metrics |
| PostgreSQL `17.9` | Stores project configuration, users, findings and analysis history |
| Docker Compose project `assms-ase-quality` | Keeps this stack's containers, network and volumes together |
| `127.0.0.1:9000` | Exposes the dashboard on this computer only |

The Compose file pins image versions. The database has no published host port. Four named volumes retain the PostgreSQL database and SonarQube data, logs and extensions. Keep `.env`, the database password and volumes together; changing the password in `.env` does not change an already initialized PostgreSQL account.

Projects use the keys `ase-assms-customer-asset-service`, `ase-assms-job-service`, `ase-assms-dispatch-service`, `ase-assms-reporting-service` and `ase-assms-frontend`. They remain empty until a scanner submits an analysis. Starting the server does not run tests or produce coverage.

## Stop and check

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Stop-SonarQube.ps1
```

Run the start command again to resume. Stopping the containers retains their volumes. Do not use `docker compose down -v` or volume pruning if you want to retain the analysis history.

Check status or inspect startup logs from this directory:

```powershell
docker compose --env-file .env -f compose.yaml ps
Invoke-RestMethod 'http://127.0.0.1:9000/api/system/status'
docker compose --env-file .env -f compose.yaml logs --tail 80 sonarqube
```

Expected server status: `UP`. Initialization writes the version, project list and login verification to `.local/setup-verification.json`; it contains no password.

If startup fails, first confirm that Docker's Linux engine is running and port 9000 is available. SonarQube also needs sufficient Docker memory and Linux limits; see the [official requirements](https://docs.sonarsource.com/sonarqube-community-build/server-installation/pre-installation/linux). This computer's limits were sufficient during setup, so no WSL settings were changed.

## Run coverage and analysis

Use Python 3.10 or newer, the .NET 8 SDK, Node.js 22.12 or newer with npm, and Java 21. Set `JAVA_HOME` to the Java installation for the frontend scanner. Keep the five application repositories beside this infrastructure repository under the same parent directory. The frontend's `package-lock.json` pins its dependencies.

From this directory, run one project or all five:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-Analysis.ps1 -Project job
powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-Analysis.ps1
```

`-Project` accepts `job`, `customer`, `dispatch`, `reporting`, `frontend` or `all`. The default is `all`. The runner uses the local SDK at `../../../temp/dotnet-sdk8/dotnet.exe` when present, otherwise the `dotnet` executable on PATH. Supply `-DotnetPath` to select another installation.

`Run-Analysis.ps1` launches `analyze.py`. Python coordinates the tools and records their results; xUnit and Vitest execute the tests. The runner creates project-scoped analysis tokens that expire after 30 days. Tokens stay in `.local/analysis-tokens.json` and are redacted from saved command lines and logs.

The backend sequence is:

1. SonarScanner for .NET `begin` loads the project's rules and connects analysis to MSBuild.
2. `dotnet build` compiles the solution with the Sonar analyzers enabled.
3. `dotnet test` runs the existing xUnit tests. Coverlet uses each repository's `quality/coverage.runsettings` to produce OpenCover and Cobertura reports.
4. SonarScanner `end` uploads the findings, OpenCover coverage and TRX test results.
5. The runner waits for SonarQube's background task to succeed, then saves metrics and the quality-gate response.

The .NET scanner version is pinned in `analysis-settings.json`. Coverlet measures the production service assembly; it excludes the test assembly from the coverage denominator. Automatic scanning of unrelated file types is disabled with `sonar.scanner.scanAll=false`.

The frontend sequence is `npm ci`, lint, production build, Vitest with V8 coverage, then standalone SonarScanner CLI. Its version and archive checksum are pinned in `analysis-settings.json`. The runner downloads it from SonarSource and checks the checksum before use. The CLI uses the installed Java 21 runtime; automatic JRE provisioning is disabled to avoid long Windows cache paths. `vitest.config.ts` includes untested production TypeScript and TSX files in coverage. Test files, test setup and declaration files are excluded from that denominator. `sonar-project.properties` identifies production and test sources; the scanner imports LCOV coverage.

The runner clears `ASSMS_DISPATCH_TEST_CONNECTION` by default, so local analysis skips Dispatch database integration tests. The CI workflow provides a disposable MySQL `dispatchdb_test` schema and runs with `-DispatchIntegrationDatabase`; a skipped Dispatch test then fails the analysis.

## Read the results

See [the measured baseline](BASELINE.md) for the completed local analyses.

The first reviewed change and its before-and-after measurements are in [the Job Service improvement record](JOB-SERVICE-IMPROVEMENT.md).

The optional-filter SQL review and its subsequent scan are in [the Job Service SQL review](JOB-SERVICE-SQL-REVIEW.md).

The four query forms were also checked against disposable MySQL; see [the Job Service MySQL filter check](JOB-SERVICE-MYSQL-CHECK.md).

The runner's nonzero exit on a rejected quality gate was checked with a temporary Job Service gate; see [the quality-gate exit check](QUALITY-GATE-CHECK.md).

For the prepared GitHub-hosted quality workflow and its first-run steps, see [the CI setup guide](CI-SETUP.md).

Each repository retains a fresh `quality/artifacts/<run-id>/` directory containing command logs, coverage reports, test results, SonarQube metrics and the quality-gate response. The infrastructure repository retains the combined `summary.json` under `.local/analysis-runs/<run-id>/`. The summary records each source revision and any uncommitted working-tree changes. Generated output is excluded from Git.

Scanner upload success and SonarQube background-task success are separate checks. The runner verifies both. Coverage must exist before upload; missing reports fail the run.

SonarQube's `coverage` metric combines line and condition coverage. The saved metrics also include `line_coverage` and `branch_coverage`. Test pass counts describe assertions; they do not indicate how much production code was exercised. Estimated technical debt (`sqale_index`) is expressed in minutes of remediation effort, not measured developer time.

Initialization assigns the **ASSMS ASE baseline** gate to the five projects. It evaluates overall coverage (minimum 35%) and duplicated lines (maximum 10%). These provisional assignment thresholds are deliberately modest; review findings and coverage before drawing conclusions about code quality. Treat security findings as items for code review, not confirmed exploitable vulnerabilities.

For automation that must fail when SonarQube returns a failed gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-Analysis.ps1 -FailOnQualityGate
```

The default run reports gate results without using them as its exit status. Build, test, coverage, scanner or background-task failures always return a nonzero exit status. The local command does not deploy to Azure. The GitHub Actions workflow runs on platform configuration changes to `dev` and can also be started manually; see [CI setup](CI-SETUP.md).

The coverage import configuration follows SonarSource's [.NET coverage](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/test-coverage/dotnet-test-coverage) and [JavaScript/TypeScript coverage](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/test-coverage/javascript-typescript-test-coverage) documentation.

For the storage and container configuration, see [SonarSource's Docker instructions](https://docs.sonarsource.com/sonarqube-community-build/server-installation/from-docker-image/set-up-and-start-container).
