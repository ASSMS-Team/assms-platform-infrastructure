# ASE quality workflow setup

The [ASE code-quality workflow](../../.github/workflows/ase-code-quality.yml) is prepared for GitHub-hosted Ubuntu. It has **not run on GitHub yet**. It starts a disposable SonarQube and PostgreSQL stack in that job, then builds, tests and analyzes the four .NET services and the frontend. It never connects to this computer's persistent SonarQube.

## First run

1. Publish the reviewed `ASE_Code_Quality_Metrics` branch in the platform repository and all five application repositories. The workflow checks out that branch from each repository. The platform push triggers a run when the workflow or `quality/sonarqube` changes. Push the platform branch after the five application branches are available remotely.
2. In the platform repository, open **Actions > ASE code quality** and inspect the push-triggered run. A manual **Run workflow** button becomes available after the workflow exists on the default branch; then select `source_ref` and `project`.
3. Read the job summary and download the `ase-code-quality-<run number>` artifact. It contains the combined analysis summary and the selected test, metric and gate results. Keep this evidence for the ASE demonstration.

No self-hosted runner, GitHub repository secret or personal token is needed for these public repositories. The job creates random, local SonarQube credentials inside the temporary hosted runner. Neither the password nor analysis tokens are uploaded as artifacts. The dashboard disappears when the job ends; the saved results remain in the GitHub artifact for 14 days. Run the local stack separately when you need an interactive dashboard with persistent history.

The workflow requires .NET 8, Node.js 22, Python 3.12, Java 21, Docker and PowerShell. It sets the Linux `vm.max_map_count` limit, waits for SonarQube to report `UP`, and verifies the checkouts and tools before scanning. The five repositories use the same requested source branch; do not interpret a mixed set of revisions as a single tested build.

Build, test, missing coverage, scanner, background-task or SonarQube gate failures stop the analysis. A separate provisional ASE check rejects measured **overall coverage below 35%** or **duplicated lines above 10%** for any selected project. These are initial demonstration floors based on the local baseline, not agreed production release targets. Adjust them with the team before treating them as release policy. The local SonarQube quality gate is unchanged.

The helper scripts and the five-project scan passed locally, but Ubuntu startup, downloads, and the complete GitHub Actions run remain unverified until the branch is published and the workflow executes. [GitHub's self-hosted runner guidance](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners) warns against attaching a personal runner to a public repository. [GitHub's manual workflow guidance](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow) explains the default-branch requirement for `workflow_dispatch`.
