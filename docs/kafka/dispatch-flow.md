# ASSMS Sprint 2 Dispatch Flow

## Purpose

This document describes the Sprint 2 dispatching flow end to end: which service publishes what, which consumer group reads it, how the outbox publisher works, and how to replay a failure without assigning a job twice.

It is the operational companion to [Event Contracts](event-contracts.md), which fixes the message shapes. This document does not redefine any payload; it describes what moves them.

## The Flow

```
Agent                Job Service          Kafka                Dispatch Service       Reporting Service
  |                       |                 |                         |                       |
  |-- POST /api/jobs ---->|                 |                         |                       |
  |                       |-- INSERT jobs   |                         |                       |
  |<---- 201 Created -----|                 |                         |                       |
  |                       |-- JobCreated -->| job-created             |                       |
  |                       |                 |------------------------>| assms-dispatch-       |
  |                       |                 |                         |   job-created         |
  |                       |                 |                         |                       |
  |                       |                 |                         |-- one transaction:    |
  |                       |                 |                         |   job_candidate_evals |
  |                       |                 |                         |   assignments         |
  |                       |                 |                         |   assignment_outbox   |
  |                       |                 |                         |                       |
  |                       |                 |<-- JobAssigned ---------| JobAssignedOutbox-    |
  |                       |                 | job-assigned            |                       |
  |                       |<----------------|                         |                       |
  |                       | assms-job-      |------------------------------------------------>|
  |                       |   job-assigned  |                         | assms-reporting-job-assigned
  |                       |-- UPDATE jobs   |                         |                       |
  |                       |   status=ASSIGNED                         |   INSERT job_assignment_projection
  |                       |                 |                         |                       |
  |                       |                 | job-created ----------------------------------->|
  |                       |                 |                         | assms-reporting-job-created
```

### Step by Step

1. An Agent creates a job. Job Service writes the `jobs` row and returns `201`, then publishes `JobCreated` to `job-created`. The publish is deliberately outside the request's success path — a broker outage must not invalidate a job that is already committed.
2. Dispatch Service reads `job-created` as `assms-dispatch-job-created`. Each event is handled in two steps:
   - **US-06A — evaluation.** `CandidateEvaluationService` resolves the required skill from the service category, normalises the region, and writes `job_candidate_evaluations` with the eligible technicians. `uq_job_candidate_evaluations_event_id` makes this idempotent on the envelope's `eventId`.
   - **US-06B — assignment.** `AutomaticAssignmentRepository.AssignFromCandidateEvaluationAsync` opens one `Serializable` transaction and, inside it, re-checks for an existing assignment `FOR UPDATE`, selects a technician from the stored candidates, writes `technician_assignments`, and queues the serialized `JobAssigned` envelope in `assignment_outbox`. Both writes commit together or neither does.

   The assignment step runs **even when the evaluation was a duplicate**. A process can fail after US-06A commits but before the assignment transaction, and skipping assignment on a duplicate evaluation would strand that job permanently.
3. Dispatch Service's `JobAssignedOutboxPublisher` polls `assignment_outbox` for rows with `published_at IS NULL`, sends each through `KafkaJobAssignedPublisher`, and marks it published only after the broker acknowledges.
4. Job Service reads `job-assigned` as `assms-job-job-assigned` and sets the job's `status` to `ASSIGNED` along with the technician columns.
5. Reporting Service reads `job-assigned` as `assms-reporting-job-assigned` and writes `job_assignment_projection`, which answers `GET /api/reports/jobs-by-technician`.

Reporting also reads `job-created` as `assms-reporting-job-created` for the jobs-by-status report. That loop is independent of everything above.

### Technician Matching

Dispatch selects a technician who meets three conditions and breaks ties in a defined order:

| Condition | Column |
| --- | --- |
| Covers the job's province | `technicians.region = ` the event's normalised `region` |
| Is available for work | `technicians.status = 'ACTIVE'` |
| Holds the required skill | `technician_skills.skill = ` the **required skill mapped from** the event's `serviceCategory` |

Among eligible technicians, the approved US-06B selection rule applies in this order:

1. **Lowest open-job count.** An assignment is open while `released_at IS NULL` and its `job_status` is neither `COMPLETED` nor `CANCELLED`.
2. **Oldest `lastAssignedAt`, with never-assigned technicians first.** A technician who has never been assigned sorts ahead of one who has, rather than being treated as assigned at the epoch or sorted last by a NULL.
3. **`technicianReference` ascending, ordinal.** Compared with `StringComparer.Ordinal` — not by locale, and not by a numeric parse of its digits — so the order does not shift with the server's culture settings.

All three levels are required for the choice to be deterministic, and an assignment nobody can reproduce is one nobody can explain afterwards.

**The code already implements exactly this rule.** `AutomaticAssignmentSelector.Select` orders by `OpenJobCount`, then by whether `LastAssignedAt` has a value (never-assigned first), then by `LastAssignedAt`, then by `TechnicianReference` under `StringComparer.Ordinal`. Four tests pin it, one per level:

- `Select_PrefersTheCandidateWithTheLowestOpenJobCount`
- `Select_WhenWorkloadTies_PrefersANeverAssignedTechnician`
- `Select_WhenWorkloadTies_PrefersTheOldestLastAssignment`
- `Select_WhenAllOtherValuesTie_UsesAscendingOrdinalReference`

An earlier draft of **this document** stated that "`technicians.id` breaks ties". That was a documentation error, not a code error — the implementation was correct all along, and the wording has been corrected here to match it. Nothing in the code needed to change.

### Required Skill Mapping

The required skill is **not** the service category itself. `JobCreated` carries a service category and a free-text problem description, and neither names a skill, so Dispatch cannot infer one safely. A business-owned mapping bridges the two:

`JobCreated` can carry five service categories, fixed by `chk_jobs_service_category` in the Job Service's `V01`. **All five must be mapped**, or jobs in the unmapped ones are silently quarantined:

| `serviceCategory` | Required skill |
| --- | --- |
| `INSTALLATION` | `AC_INSTALLATION` |
| `REPAIR` | `AC` |
| `MAINTENANCE` | `AC_MAINTENANCE` |
| `INSPECTION` | `AC_INSPECTION` |
| `WARRANTY_CLAIM` | `AC_WARRANTY` |

```json
"CandidateMatching": {
  "RequiredSkillByServiceCategory": {
    "INSTALLATION": "AC_INSTALLATION",
    "REPAIR": "AC",
    "MAINTENANCE": "AC_MAINTENANCE",
    "INSPECTION": "AC_INSPECTION",
    "WARRANTY_CLAIM": "AC_WARRANTY"
  }
}
```

`REPAIR` maps to `AC` rather than `AC_REPAIR`, and that inconsistency is deliberate: `AC` is the value already configured and already held by staging technicians in `technician_skills`. Renaming it would orphan every existing technician's skill row and stop `REPAIR` jobs matching. **Normalising it is a business decision, not a deployment one** — if the team wants `AC_REPAIR`, the configuration and every technician's skills have to change together.

The skill string must equal a `technician_skills.skill` value character for character. Only the category side of the lookup is case-insensitive.

**A service category with no configured mapping is quarantined, not guessed:** `RequiredSkillResolver.TryResolve` returns false, `CandidateEvaluationService` returns `UnmappedServiceCategory`, the consumer commits past the event, and nothing is written anywhere — no evaluation row, no log of a business failure, nothing for a Dispatcher to find. Adding a sixth service category upstream without adding its mapping here makes every job in that category vanish.

`RequiredSkillMappingTests` guards this: `CompleteMapping_CoversEveryServiceCategoryJobCreatedCanCarry` fails if the category list and the mapping ever disagree.

### When Nobody Qualifies

If no technician qualifies, the transaction is **committed, not rolled back**. `MarkNoCandidateAsync` sets the evaluation's `evaluation_status` to `NO_CANDIDATE`, zeroes `candidate_count`, and raises `requires_dispatcher_attention`; the consumer logs a warning naming the job and commits the offset.

Committing is the right call here: the evaluation genuinely happened and its result — that nobody was eligible — is a fact worth keeping, and holding the topic on a job nobody can take would stop every job behind it as well. The flag is how a Dispatcher finds these jobs afterwards:

```sql
SELECT job_id, job_reference, required_skill, normalized_region, evaluated_at
FROM job_candidate_evaluations
WHERE requires_dispatcher_attention = TRUE
ORDER BY evaluated_at DESC;
```

Note the consequence for replay: because the evaluation **is** recorded, replaying `job-created` after hiring a technician will not assign the job — the evaluation is a duplicate, and the assignment step then finds the stored candidate list, which was empty. Such a job has to be assigned by a Dispatcher, or its evaluation row cleared first. See the replay procedure below.

## The Outbox Publisher

### Why It Exists

Writing the assignment and publishing the event are two systems with no transaction spanning them. Publishing first risks announcing an assignment that was never written. Writing first and publishing after — which is what Job Service does for `JobCreated` today — risks an assignment nobody downstream ever hears about, with nothing retrying.

The outbox closes the gap by making the intent to publish part of the same commit as the fact. Either the assignment and its queued event both exist, or neither does.

### How It Works

`assignment_outbox` stores the **complete serialized envelope**, not just the payload. The `eventId` and `occurredAt` are fixed when the assignment commits, so every retry sends byte-identical content. Building the envelope at publish time instead would mint a fresh `eventId` on each attempt and defeat every consumer's deduplication.

`JobAssignedOutboxPublisher` is a `BackgroundService` that, every 5 seconds:

- reads up to **20** pending rows with
  `SELECT ... FROM assignment_outbox o JOIN technician_assignments a ON a.id = o.assignment_id WHERE o.published_at IS NULL ORDER BY o.created_at, o.id`
  — ordered by creation time then id, so events about one job are published in the order they were written, and joined to the assignment because the Kafka message key is the `job_id`;
- publishes each through `KafkaJobAssignedPublisher`, configured `Acks.All` with `EnableIdempotence = true`, and **awaits the broker's acknowledgement**;
- sets `published_at` only after that acknowledgement, via an update guarded `WHERE id = @id AND published_at IS NULL`;
- on failure increments `publish_attempts`, stores the reason in `last_error` (truncated to 1000 characters), leaves `published_at` NULL, and continues to the next row.

Nothing ever gives up on a row. A message that cannot be published stays in the table and is retried on every pass until it succeeds, so a broker outage delays publication rather than losing it.

`publish_attempts` and `last_error` are what make a stuck message diagnosable from the table itself, after the logs have rotated away.

**One caveat worth knowing:** a failing row does not stop the pass, so if two events for the same job are pending and the first fails while the second succeeds, they reach the topic out of order. Today that cannot happen — `uq_technician_assignments_job` allows only one assignment per job, so a job never has two pending events. US-15 lifts that constraint and must revisit this loop at the same time.

### Duplicate Publishing Is Expected

If the process dies between the broker's acknowledgement and the `published_at` update, the row is published again on the next start. That is deliberate: it is the at-least-once delivery every ASSMS consumer already deduplicates against, and it is the safe direction to fail in. Losing an event is unrecoverable; sending it twice is not.

## Idempotency

Five guards make the flow replayable without duplicate business effects. Every one of them is a database constraint or a SQL predicate — none relies on the application remembering anything, because a restarted process remembers nothing.

| Guard | Where | Stops |
| --- | --- | --- |
| `uq_job_candidate_evaluations_event_id` on `event_id` | Dispatch, `V03` | The same `JobCreated` event being evaluated twice |
| `uq_technician_assignments_job` on `job_id` | Dispatch, `V02` | One job being assigned twice, including two consumers racing |
| `uq_assignment_outbox_assignment` on `assignment_id` | Dispatch, `V04` | A duplicate `JobAssigned` being queued for one assignment |
| `WHERE ... published_at IS NULL` on both outbox updates | Dispatch | A late acknowledgement re-marking a row another pass already published |
| `assigned_at IS NULL OR assigned_at < @assignedAt` | Job Service, `V02` | A redelivered or stale assignment overwriting a newer one |
| `job_assignment_projection` primary key on `job_id` | Reporting, `V02` | A redelivery double-counting in the report |

**There is no separate `processed_events` table, and none is needed.** `job_candidate_evaluations` already carries a unique index on the envelope's `eventId`, which is the event-deduplication ledger this flow requires. An earlier draft of this document proposed adding one as `V03`; that number is taken by `job_candidate_evaluations`, and the table would have duplicated a guard that already exists.

Every consumer writes its row **before** committing its Kafka offset. A crash between the two guarantees a redelivery, and every guard above is what makes that redelivery a no-op.

The Dispatch assignment transaction also handles error `1062` explicitly: if two consumers reach the insert at the same instant, the loser's duplicate-key failure is caught, rolled back, and reported as `AlreadyAssigned` rather than surfacing as an error. The unique index is the final arbiter, not the `FOR UPDATE` read that precedes it.

## Replay Procedure

Replaying means resetting a consumer group's offsets so it re-reads messages it has already seen. It is safe in this flow because of the guards above, but it is not free — read the whole procedure before running it.

### Before You Start

- Stop the service whose group you are resetting. `kafka-consumer-groups.sh --reset-offsets` refuses to run while the group has active members, and stopping it is what makes the reset take effect cleanly rather than being overwritten.
- Know which group you mean. The five groups are listed in [Event Contracts](event-contracts.md#topics-producers-and-consumer-groups).

### Replaying Dispatch (`assms-dispatch-job-created`)

Use this when jobs were not assigned — most often because no technician covered the region at the time.

```bash
# 1. Stop the Dispatch Service container.

# 2. Preview. --dry-run prints what would change and alters nothing.
sudo docker run --rm apache/kafka:4.3.1 \
  /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server 10.20.2.4:9092 \
  --group assms-dispatch-job-created \
  --topic job-created \
  --reset-offsets --to-earliest --dry-run

# 3. Apply, once the preview reads as expected.
sudo docker run --rm apache/kafka:4.3.1 \
  /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server 10.20.2.4:9092 \
  --group assms-dispatch-job-created \
  --topic job-created \
  --reset-offsets --to-earliest --execute

# 4. Start the Dispatch Service container and watch its log.
```

Every job already assigned is logged as *"Ignoring repeat assignment processing"* and changes nothing: the evaluation collides with `uq_job_candidate_evaluations_event_id`, and the assignment step finds the existing row under `uq_technician_assignments_job`. Only a job whose assignment never committed is assigned, and it produces exactly one new `JobAssigned`.

**A replay will not rescue a `NO_CANDIDATE` job.** Its evaluation row already exists with an empty candidate list, so the replay records a duplicate evaluation and then finds nothing to select. To make such a job assignable again, delete its evaluation first — the candidate rows go with it — and then replay:

```sql
DELETE c FROM job_candidate_evaluation_candidates c
JOIN job_candidate_evaluations e ON e.id = c.evaluation_id
WHERE e.job_id = '<the job id>';

DELETE FROM job_candidate_evaluations WHERE job_id = '<the job id>';
```

Do this only for jobs that were genuinely never assigned. Deleting the evaluation for a job that *does* have an assignment is harmless — `uq_technician_assignments_job` still refuses a second — but it discards the audit of why that technician was chosen.

`--to-earliest` replays the whole topic. To replay a narrower window use `--to-datetime 2026-09-14T00:00:00.000` or `--shift-by -50` instead.

### Replaying Reporting or Job Service

The same three commands with `--group assms-reporting-job-assigned --topic job-assigned`, or `--group assms-job-job-assigned --topic job-assigned`, or `--group assms-reporting-job-created --topic job-created`.

These are projections and status updates rather than decisions, so replaying them is cheaper than replaying Dispatch: the upserts rewrite rows to the values they already hold.

### Republishing From the Outbox

If `JobAssigned` was never published — the assignment exists but no consumer saw it — do **not** replay `job-created`. Both Dispatch guards are already satisfied, so the replay correctly does nothing. Fix it from the outbox instead:

```sql
-- What is stuck, and why.
SELECT o.id, o.assignment_id, a.job_id, o.publish_attempts, o.last_error, o.created_at
FROM assignment_outbox o
JOIN technician_assignments a ON a.id = o.assignment_id
WHERE o.published_at IS NULL
ORDER BY o.created_at, o.id;
```

The publisher retries these on its own every 5 seconds, indefinitely, so an unreachable broker needs no intervention beyond fixing the broker. A row with a high `publish_attempts` and a repeating `last_error` is one to investigate rather than wait on.

To force a re-publish of a row that was marked published but demonstrably never arrived:

```sql
-- Re-queue one event. The envelope is stored as written, so it goes out with
-- its original eventId and both consumers deduplicate it if it did in fact
-- arrive - Job Service on the assigned_at guard, Reporting on the job_id key.
UPDATE assignment_outbox
SET published_at = NULL, publish_attempts = 0, last_error = NULL
WHERE assignment_id = '<the assignment id>';
```

This is safe precisely because the stored envelope is immutable: `payload` is written once, inside the assignment transaction, and never rebuilt. Re-queueing cannot produce a second distinct event for one assignment.

### Diagnosing a Failure

| Symptom | Look at |
| --- | --- |
| Job created but never assigned | `job_candidate_evaluations WHERE requires_dispatcher_attention = TRUE`; then `technicians` and `technician_skills` for that region and required skill |
| Job quarantined, no evaluation row at all | Dispatch log for `UnmappedServiceCategory` — the service category has no entry in `CandidateMatching:RequiredSkillByServiceCategory` |
| Assignment exists, nobody downstream knows | `assignment_outbox WHERE published_at IS NULL`, and its `publish_attempts` and `last_error` |
| Job Service still shows `CREATED` | Job Service log for the `job-assigned` subscription line; then consumer group lag |
| Report missing a technician | `job_assignment_projection` for that `technician_id`; a technician with no assignments is absent by design |
| A consumer appears stuck | `kafka-consumer-groups.sh --describe --group <group>` and read `LAG` |

```bash
sudo docker run --rm apache/kafka:4.3.1 \
  /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server 10.20.2.4:9092 \
  --describe --group assms-dispatch-job-created
```

## Known Limits

These are deliberate Sprint 2 boundaries, recorded so they are decisions rather than surprises.

- **One assignment per job, ever — and this constraint is temporary.** `uq_technician_assignments_job`, a unique index on `technician_assignments.job_id` (`V02`), forbids a second assignment for any job. `technician_assignments` already carries a `released_at` column that is never populated by this flow, because nothing can currently release an assignment.

  **US-15 must replace it.** The replacement model has to satisfy two requirements at once, and a unique key on `job_id` cannot express either:

  1. **Assignment history is preserved.** Every assignment a job has ever had remains queryable, including superseded ones, with who it was assigned to and when. Reassignment must not overwrite or delete the prior record — an audit of "who was sent to this job, and when did that change" has to be answerable after the fact.
  2. **Exactly one assignment is current.** At most one row per job may be the active assignment at any instant, and the constraint must be enforced by the database rather than by application convention — enforced in code alone, two concurrent reassignments race and both become current.

  The usual shape is a generated column that is the `job_id` only while `released_at IS NULL` and NULL otherwise, carrying a unique index: MySQL permits many NULLs under a unique key, so history accumulates freely while at most one active row per job remains possible. The existing `released_at` column is the natural discriminator. Whatever shape is chosen, dropping `uq_technician_assignments_job` without putting an equivalent guarantee in its place would silently reintroduce double assignment — the exact failure this flow's idempotency guards exist to prevent.

  US-15 must also revisit two things that depend on the current constraint: the outbox publisher's ordering (see the caveat above — a job can then have two pending events) and Job Service's `assigned_at` guard, which is already written to handle a second, later assignment but has never had one to handle.
- **One region per technician.** `technicians.region` is a single column; a technician covering several provinces needs a coverage table.
- **Kafka is `PLAINTEXT` with no SASL or TLS.** Privacy rests entirely on the Azure NSG restricting port 9092 to the service subnets. Acceptable for staging; it is not acceptable for production and must be raised before any production deployment.
- **The staging broker binds `0.0.0.0:9092`.** The NSG is the only thing keeping it private. Binding `10.20.2.4:9092:9092` would add defence in depth.
- **Single broker, replication factor 1.** `Acks.All` is therefore currently no stronger than `Acks.Leader`. It is set so that adding brokers later is a broker change, not a correctness change nobody remembered to make.
- **A technician with no assignments never appears in jobs-by-technician.** Reporting projects assignments, not technicians, so it cannot know an idle technician exists. A report that must show them has to be answered by Dispatch, which owns the roster.
- **`JobStatusChanged` is still undefined** and nothing implements it.
