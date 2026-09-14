# ASSMS Staging Kafka Deployment

## Purpose

How to run and verify the staging Kafka broker, and how to confirm the Sprint 2 dispatch flow works end to end against it.

The message flow itself, the outbox publisher and the replay procedure are documented in [Dispatch Flow](../kafka/dispatch-flow.md).

## Kafka Must Stay Private

The broker has **no public IP, no public SSH rule, and no public `9092` rule**, and it must stay that way. Access is over the private network only, from the ASSMS service subnets, which the NSG already permits.

| | |
| --- | --- |
| VM | `vm-assms-kafka-staging` |
| Private IP | `10.20.2.4` |
| Endpoint for backend services | `10.20.2.4:9092` |

The NSG rule is defined as `AllowKafkaFromServicesSubnet` in `terraform/environments/staging/main.tf`. There is no authentication on the broker — it runs `PLAINTEXT` — so that NSG rule is the only thing keeping it private. Treat any change to it as a security change.

## 1. Deploy the Compose Configuration

Use `kafka/docker/docker-compose.staging.yml`. It differs from the local `docker-compose.yml` in exactly two ways, and both matter:

```yaml
ports:
  - "9092:9092"          # local binds 127.0.0.1 only

KAFKA_ADVERTISED_LISTENERS: INTERNAL://kafka:29092,EXTERNAL://10.20.2.4:9092
```

**Do not deploy the local Compose file unchanged.** It advertises `localhost`, so a client on another VM would connect once, be told to talk to `localhost:9092`, and fail on every subsequent request.

### Preferred: Bind to the Private IP Explicitly

`"9092:9092"` binds `0.0.0.0`, which means the NSG is the *only* thing keeping the broker private. Binding the private address explicitly adds defence in depth, so that a future NSG mistake does not by itself expose an unauthenticated broker:

```yaml
ports:
  - "10.20.2.4:9092:9092"
```

This is the preferred configuration, but **verify it on the VM before adopting it**. Docker refuses to start a container when the requested bind address is not present on the host, so if the VM's private address is assigned late, differs from `10.20.2.4`, or moves, this turns a working broker into one that will not start. Confirm with `ip -4 addr show` on the VM, change it, then re-run the verification in section 2 in full.

Until that is verified, `"9092:9092"` stays as-is and the NSG carries the whole guarantee.

Copy both files to the VM:

```text
/opt/assms/kafka/docker/docker-compose.staging.yml
/opt/assms/kafka/scripts/create-topics.sh
```

The `topic-init` service mounts `../scripts`, which resolves to `/opt/assms/kafka/scripts` from that Compose file's location. Keep the two paths in that relative arrangement or topic creation will fail.

## 2. Start and Verify the Broker

Run through Azure VM Run Command:

```bash
sudo docker compose -f /opt/assms/kafka/docker/docker-compose.staging.yml up -d
sudo docker compose -f /opt/assms/kafka/docker/docker-compose.staging.yml ps
sudo docker compose -f /opt/assms/kafka/docker/docker-compose.staging.yml logs --tail=100 kafka
sudo docker compose -f /opt/assms/kafka/docker/docker-compose.staging.yml logs --tail=100 topic-init
```

Expected:

- `assms-kafka` is healthy.
- `assms-kafka-topic-init` has exited with code `0`.

Check the topics:

```bash
sudo docker exec assms-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --list
```

All three must be present:

```text
job-created
job-assigned
job-status-changed
```

If one is missing, `topic-init` did not complete. Read its log before creating the topic by hand — a missing topic is usually a symptom, not the problem. To create one directly:

```bash
sudo docker exec assms-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists \
  --topic job-created \
  --partitions 1 \
  --replication-factor 1
```

`KAFKA_AUTO_CREATE_TOPICS_ENABLE` is `false`, so a topic that does not exist will not appear on first use. That is intentional: it makes a typo in a topic name fail loudly rather than silently creating a topic nobody reads.

## 3. Configure the Backend Services

Every staging environment file must set:

```text
Kafka__BootstrapServers=10.20.2.4:9092
```

Required in all three services — Job, Dispatch and Reporting. Each reads the value as `Kafka:BootstrapServers` and **throws at startup if it is absent**. That is deliberate: a service silently defaulted to `localhost` would start, log nothing alarming, and process nothing.

No secret belongs in this configuration. The broker has no credentials, and none of these values is sensitive.

## 4. Apply Migrations

| Service | Migrations |
| --- | --- |
| Dispatch | `V01__create_technicians.sql`, `V02__create_technician_assignments.sql`, `V03__create_job_candidate_evaluations.sql`, `V04__create_assignment_outbox.sql` |
| Reporting | `V01__create_job_projection.sql`, `V02__add_job_assignment_projection.sql` |
| Job | `V01__create_jobs.sql`, `V02__add_job_assignment.sql` |

All three services now apply their own migrations, and **none of them does it on startup**. Each runs the published image once with a flag, as its own deployment step, and exits:

```bash
sudo docker run --rm --env-file /etc/assms/<service>.env <image>:<sha> --apply-migrations
```

Each staging CD workflow runs that line after loading the image and **before** replacing the running container, so a failed migration aborts the deployment rather than leaving a service running against a half-migrated schema. Migrating on startup instead would let several instances race the same `ALTER`.

Applied filenames are recorded in a `schema_migrations` table in each database, so re-running the step is a no-op.

`V02__add_job_assignment.sql` adds `assignment_id`, `assigned_technician_id`, `assigned_technician_reference` and `assigned_at` to `jobs`. It is guarded against `information_schema`, so running it twice is a no-op rather than error 1060 — which also means a partially applied run can simply be repeated.

**Until Job Service's `V02` has been applied, its `JobAssigned` consumer fails on every message with an unknown-column error.** The consumer does not commit those offsets, so nothing is lost: apply the migration, restart, and the backlog is processed.

**Do not renumber, replace or duplicate any existing migration.** Dispatch's `V01`–`V04` are already on `dev`. An earlier draft of this document proposed a `V03__create_processed_events.sql`, which collides with the existing `V03` for job candidate evaluations — and the table was unnecessary in any case, because `uq_job_candidate_evaluations_event_id` already provides the event-deduplication guard. Any genuinely new Dispatch schema takes the next free number, `V05`.

Confirm each service's deployment log shows its migrations completing.

### Seed an Eligible Technician

Nothing can be assigned until Dispatch holds a technician who matches, and `database/seed.sql` is a placeholder — it seeds nothing. Create one through the API, as a Dispatcher or Manager:

```text
POST /api/technicians
```

The technician must be `ACTIVE`, cover the job's region, and hold the **mapped required skill** for the job's service category. That mapping is configuration, not a constant: `CandidateMatching:RequiredSkillByServiceCategory` in each environment's settings maps a service category onto the skill Dispatch looks for. A category with no mapping is quarantined rather than assigned, so confirm the mapping exists for whatever category the evidence flow uses.

Use non-sensitive test data only.

## 5. Restart the Consumers

Restart or recreate the Dispatch, Job and Reporting containers **after** the broker is healthy and the topics exist, so their consumers subscribe cleanly rather than retrying against a broker that was not there.

Each service logs its subscription on startup. Confirm you see one line per loop:

```text
Subscribed to job-created as group assms-dispatch-job-created.
Subscribed to job-assigned as group assms-job-job-assigned.
Subscribed to job-created as group assms-reporting-job-created.
Subscribed to job-assigned as group assms-reporting-job-assigned.
```

Dispatch does not log a separate outbox startup line; the first evidence its publisher is running is a `Published JobAssigned event ...` line after the first assignment.

Then confirm the groups exist, from a VM that can reach Kafka privately:

```bash
sudo docker run --rm apache/kafka:4.3.1 \
  /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server 10.20.2.4:9092 \
  --list
```

Expected — **four** groups, not three:

```text
assms-dispatch-job-created
assms-job-job-assigned
assms-reporting-job-created
assms-reporting-job-assigned
```

A consumer group does not exist until a consumer has joined it, so a missing group means that service did not start or could not reach the broker. Check the service log before touching the broker.

## 6. End-to-End Verification

1. Sign in with a Manager account.
2. Confirm an `ACTIVE` technician exists in `WESTERN` holding the skill that `CandidateMatching:RequiredSkillByServiceCategory` maps `REPAIR` to.
3. Create a `REPAIR` job in region `WESTERN`.
4. Dispatch log shows the `JobCreated` consumption and a line naming the technician, the assignment id, and the queued event id.
5. Dispatch log shows the outbox publish, with the topic, partition and offset.
6. Job Service log shows the job moving to `ASSIGNED`.
7. Reporting log shows the `JobAssigned` projection.
8. Call the report:

```text
GET /api/reports/jobs-by-technician
```

The assigned technician appears with a count of at least 1.

### Evidence to Capture

- Healthy Kafka container (`docker compose ps`)
- Topic list
- Consumer group list — all four
- Successful CI/CD runs
- The created job
- The technician assignment
- The jobs-by-technician report result

### Proving Idempotency

The completion criterion is that failures are replayable *without duplicate business effects*, so it is worth demonstrating rather than asserting. Replay the Dispatch group per the [replay procedure](../kafka/dispatch-flow.md#replay-procedure), then confirm:

- the Dispatch log reads *"was already assigned on an earlier delivery"* for the existing job;
- `SELECT COUNT(*) FROM technician_assignments WHERE job_id = '<job>'` is still `1`;
- the jobs-by-technician count is unchanged.

That is the evidence that replay is safe, and it is worth a screenshot.
