# ASE quality workflow

The [ASE code-quality workflow](../../.github/workflows/ase-code-quality.yml) builds, tests and analyzes the four .NET services and the frontend on a GitHub-hosted Ubuntu runner. It starts a disposable SonarQube and PostgreSQL stack for each run. It does not use this computer's persistent SonarQube or deploy to Azure.

## Run against dev

The workflow runs automatically when its own workflow file or `quality/sonarqube` configuration changes on the platform repository's `dev` branch. On those pushes it checks out `dev` from all five application repositories. Changes pushed only to an application repository do **not** trigger this platform workflow; launch it manually after those merges.

With GitHub CLI available as `gh` and signed in:

```powershell
gh workflow run ase-code-quality.yml -R ASSMS-Team/assms-platform-infrastructure --ref dev -f source_ref=dev -f project=all
```

Choose `project=job`, `customer`, `dispatch`, `reporting` or `frontend` for a focused run. The workflow summary shows each project's test count, coverage, quality-gate result and analysis status. Download the `ase-code-quality-<run number>` artifact from the run for saved JSON metrics, gate responses and test results. Artifacts are retained for 14 days. Keep the run URL and downloaded artifact as assignment evidence.

## What the gate checks

Build, test, missing coverage, scanner, background-task or SonarQube quality-gate failures stop the job. The workflow creates an **ASSMS ASE baseline** gate and assigns it to all five projects. It evaluates overall coverage below 35% and duplicated lines above 10%; the metric check independently verifies these values and requires two evaluated gate conditions. These are demonstration floors, not agreed production release targets. The same gate is configured on the local SonarQube server when `Start-SonarQube.ps1` initializes it.

The workflow sets up .NET 8, Node.js 22, Python 3.12 and Java 21; adjusts the hosted Linux `vm.max_map_count` limit; starts SonarQube; and verifies all checkouts and tools before scanning. It needs no personal self-hosted runner or repository secret because the six repositories are public and temporary SonarQube credentials are generated inside the job. Credentials and analysis tokens are not uploaded. The interactive SonarQube dashboard disappears when the runner is removed; the artifact retains the recorded results.

The runner starts a disposable MySQL service with a dedicated `dispatchdb_test` schema and synthetic CI-only credentials. `-DispatchIntegrationDatabase` passes that connection only to Dispatch's test process. Its integration tests apply their own migrations and clear only this scratch schema. The analysis fails if a Dispatch test remains skipped. Running the analysis locally without that switch still leaves these database tests skipped by default; never point the switch at staging or production data.
