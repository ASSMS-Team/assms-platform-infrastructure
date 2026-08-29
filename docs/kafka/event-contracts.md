# ASSMS Kafka Event Contracts

## Purpose

This document is the cross-repository contract for the events ASSMS services exchange over Kafka. It fixes the envelope every event carries, the message key, the serialization format, and the naming rules, and it defines the full `JobCreated` payload.

The topics themselves are already created by the local development foundation described in [Local Kafka Development](local-development.md). This document adds the message contract that producers and consumers must agree on; it does not change topic creation.

Producers must not publish a field this document does not define, and consumers must not depend on a field this document does not define.

## Topics, Producers, and Consumer Groups

Three business topics exist. Each is produced by exactly one service, and each consuming service reads with its own consumer group so that every service receives its own copy of the event.

| Topic | Producer | Consumer | Consumer group |
| --- | --- | --- | --- |
| `job-created` | Job Service | Dispatch Service | `assms-dispatch-job-created` |
| `job-created` | Job Service | Reporting Service | `assms-reporting-job-created` |
| `job-assigned` | Dispatch Service | Job Service | `assms-job-job-assigned` |
| `job-assigned` | Dispatch Service | Reporting Service | `assms-reporting-job-assigned` |
| `job-status-changed` | Job Service | Reporting Service | `assms-reporting-job-status-changed` |

The rule behind the group names is that Dispatch and Reporting must never share a group on `job-created`. A shared group would make Kafka deliver each event to only one of them, and both need it independently.

## Envelope Convention

Every message on every ASSMS topic is a JSON object with the same six top-level fields. Event-specific data lives only inside `payload`; the other five fields are identical in shape across all three topics.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `eventId` | string (UUID) | yes | Unique id of this event instance. A redelivery of the same event carries the same `eventId`, so consumers use it to detect duplicates. |
| `eventType` | string | yes | The event name in PascalCase, for example `JobCreated`. Lets a consumer route without inspecting the payload. |
| `eventVersion` | integer | yes | Schema version of `payload`. See below. |
| `occurredAt` | string (ISO 8601, UTC) | yes | When the business fact happened in the producing service, not when the message was published. |
| `producer` | string | yes | Service that emitted the event, using the repository service name, for example `job-service`. |
| `payload` | object | yes | The event-specific body. Its fields are defined per event type and version. |

### What `eventVersion` Means

`eventVersion` describes the shape of `payload` only. It starts at `1` for every event type and is an integer, not a semantic version — there is no minor or patch component.

The rules for changing a payload are:

- **Adding an optional field does not change `eventVersion`.** Consumers must ignore fields they do not recognise, so a new optional field is safe to add in place.
- **Removing a field, renaming a field, changing a field type, or changing the meaning of an existing field increments `eventVersion`.** These break existing consumers.
- A producer raising `eventVersion` publishes both versions to the same topic until every consumer has been updated. Consumers must branch on `eventVersion` and must not assume there is only one version on a topic.
- An unrecognised, higher `eventVersion` must be treated as an event the consumer cannot process yet, not as a malformed message.

Because `eventVersion` covers the payload alone, an envelope change would affect all three topics at once and is out of scope for a single event version number.

## `JobCreated`

Published by Job Service to `job-created` when a new job has been persisted. Envelope values are `eventType` `JobCreated`, `eventVersion` `1`, and `producer` `job-service`.

### Payload Fields

These are the fields as Job Service actually publishes them, matching the `jobs` table it writes.

| Field | Type | Nullable | Description |
| --- | --- | --- | --- |
| `jobId` | string (UUID) | no | Server-generated id of the job. Also the message key. |
| `jobReference` | string | no | Human-readable handle, `JOB-` followed by six characters, unique across all jobs. This is what an Agent quotes to a customer, so a consumer displaying a job shows this rather than `jobId`. |
| `customerId` | string (UUID) | no | Customer the job belongs to, as held by the Customer & Asset Service. |
| `assetId` | string (UUID) | no | Asset the job is raised against, as held by the Customer & Asset Service. |
| `serviceCategory` | string | no | Kind of work: `INSTALLATION`, `REPAIR`, `MAINTENANCE`, `INSPECTION` or `WARRANTY_CLAIM`. |
| `problemDescription` | string | no | What the customer reported. Up to 1000 characters. |
| `priority` | string | no | `LOW`, `MEDIUM`, `HIGH` or `URGENT`. |
| `region` | string | no | Sri Lankan province the work is in: `WESTERN`, `CENTRAL`, `SOUTHERN`, `NORTHERN`, `EASTERN`, `NORTH_WESTERN`, `NORTH_CENTRAL`, `UVA` or `SABARAGAMUWA`. This is what Dispatch matches against technician coverage. |
| `status` | string | no | Lifecycle status at creation. Always `CREATED` in this event. |
| `createdAt` | string (ISO 8601, UTC) | no | Database timestamp for when the job row was created. |

Enumerated values are `UPPER_SNAKE_CASE`, ids are GUID strings, and timestamps are UTC in ISO 8601 — the same conventions the ASSMS REST APIs already use.

`status` is present even though it is always `CREATED` here, so that a consumer can read the status field the same way across `job-created` and the later `job-status-changed`.

`region` is a province, not a street address. It is the field Dispatch filters on, and the `jobs` table indexes it for exactly that query. The address of the work is held against the asset in the Customer & Asset Service and is not duplicated onto the event.

Two columns on the `jobs` table are deliberately not published. `scheduledDate` is null on every row until a later story schedules work, and `createdBy` holds a placeholder until authentication exists; publishing either would put a value on the wire that means nothing. Both are additive when they carry real values, which under the versioning rules above does not change `eventVersion`.

### Example Message

Key: `9f1c7a24-8f4e-4c3a-9a52-2b6d0f5e1a77`

```json
{
  "eventId": "3d2a1b90-6c77-4f18-b0a1-5c9e7d4a2f31",
  "eventType": "JobCreated",
  "eventVersion": 1,
  "occurredAt": "2026-08-29T09:14:32.118Z",
  "producer": "job-service",
  "payload": {
    "jobId": "9f1c7a24-8f4e-4c3a-9a52-2b6d0f5e1a77",
    "jobReference": "JOB-7K2M9X",
    "customerId": "c41b9e2d-77a3-4d5f-8e10-6b2c9a0f4d13",
    "assetId": "a70e5c18-2d94-4b6a-9f37-1e8d5c3b7a62",
    "serviceCategory": "REPAIR",
    "problemDescription": "Air conditioner in the server room is not cooling and trips the breaker after ten minutes.",
    "priority": "HIGH",
    "region": "WESTERN",
    "status": "CREATED",
    "createdAt": "2026-08-29T09:14:32.118Z"
  }
}
```

### Why This Is Still `eventVersion` 1

An earlier draft of this document named these fields `jobType`, `description` and `location`, carried `scheduledDate` and `createdBy`, and gave the creation status as `PENDING`. That draft was written before the `jobs` table existed and never described anything that was published: no producer implemented it, and no consumer read it.

Correcting a payload that was never on the wire is not a schema change, so `eventVersion` stays at `1`. The rules above apply from this version onward — the next rename or removal of a field in this table does increment it.

## Message Key

Every message on every ASSMS topic is keyed by `jobId`, serialized as the plain UUID string with no quotes and no JSON wrapping. The key is not a substitute for the `jobId` inside the payload; it is present in both places, and the two must always match.

`jobId` is the key because Kafka guarantees ordering within a partition only, and it routes by key hash. Keying by `jobId` puts every event about one job — its creation, its assignment, and each of its status changes — on the same partition, in the order the producing services published them. A consumer therefore never sees a job assigned before it was created, or an older status after a newer one, for that job.

Ordering is guaranteed per job, not across jobs. Two different jobs may be processed in any relative order, which is correct: nothing in ASSMS depends on the relative ordering of unrelated jobs.

A null key would round-robin the events of a job across partitions and lose that ordering, so a null key is not permitted. This also keeps the contract valid when the local single-partition topics are later given more partitions in staging.

## Serialization

- Messages are **JSON**, UTF-8 encoded, with no schema registry and no Avro or Protobuf.
- The key is a **UTF-8 string**. Producers use a string serializer for the key and a JSON serializer for the value.
- JSON property names are **camelCase**, matching the ASP.NET Core default the ASSMS REST APIs already use.
- Timestamps are **UTC, ISO 8601** — `2026-08-29T09:14:32.118Z`. Dates with no time of day are `YYYY-MM-DD`.
- Ids are **GUID strings** in canonical hyphenated lowercase form.
- Enumerated values are **`UPPER_SNAKE_CASE`** strings, never integers, so that adding a value does not shift the meaning of existing data.
- A field with no value is serialized as `null` and is not omitted, so consumers can distinguish an absent value from an unknown field.

## Naming Convention

| Item | Convention | Examples |
| --- | --- | --- |
| Topic name | lowercase, hyphen-separated, singular subject then past-tense verb | `job-created`, `job-assigned`, `job-status-changed` |
| `eventType` | PascalCase, past tense, matching its topic | `JobCreated`, `JobAssigned`, `JobStatusChanged` |
| Consumer group | `assms-<consuming-service>-<topic>` | `assms-dispatch-job-created`, `assms-reporting-job-status-changed` |
| `producer` | the repository service name, lowercase and hyphen-separated | `job-service`, `dispatch-service` |
| Payload field | camelCase | `jobId`, `serviceCategory` |

Event names are past tense because an event records something that has already happened. A topic and its `eventType` always describe the same fact in the two casings above, so `job-status-changed` carries `JobStatusChanged` and nothing else.

## Sprint 2 Scope

**`JobAssigned` and `JobStatusChanged` payloads are not defined yet.** Both are Sprint 2 work.

What is already fixed for them in Sprint 1 is everything outside the payload: their topics exist, their producer and consumer-group mapping is in the table above, they will carry the same six-field envelope, they will be keyed by `jobId`, and they will use the same JSON serialization and naming rules. Only the contents of their `payload` objects remain open.

Nothing may be implemented against a guessed `JobAssigned` or `JobStatusChanged` payload. This document must be extended with their field lists and example messages in Sprint 2, before Dispatch Service produces `job-assigned` or Job Service produces `job-status-changed`.
