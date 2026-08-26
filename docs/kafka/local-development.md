# Local Kafka Development

## Purpose

This environment provides one Apache Kafka node for ASSMS local development. The node runs in KRaft combined broker/controller mode; ZooKeeper is not used. This foundation does not include application producers, consumers, or production event contracts.

## Prerequisites

- Docker Desktop or another Docker engine with Docker Compose v2
- Port `9092` available on the developer machine
- Bash only when using the optional helper scripts; the Docker Compose commands work in PowerShell and other shells

## Start Kafka

From `kafka/docker`:

```bash
docker compose up -d
docker compose ps
```

The broker is ready when `assms-kafka` is shown as healthy. The one-shot `topic-init` service waits for Kafka and creates the required topics. It may be shown as exited with code 0 after successful initialization.

From a Bash-compatible shell, the equivalent helper is:

```bash
./kafka/scripts/start-kafka.sh
```

Run that helper from the repository root.

## Stop Kafka

From `kafka/docker`:

```bash
docker compose down
```

This keeps the named Kafka data volume. To intentionally remove local Kafka data, use `docker compose down --volumes`.

The Bash helper from the repository root is:

```bash
./kafka/scripts/stop-kafka.sh
```

## Check Broker Readiness

From `kafka/docker`:

```bash
docker compose ps
docker compose exec kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server kafka:29092
```

The first command should show a healthy Kafka container. The second should return broker API information.

## Create Topics

Topic initialization is automatic on `docker compose up -d`. It is safe to run again because topic creation uses `--if-not-exists`:

```bash
docker compose run --rm topic-init
```

The local single-node defaults are one partition and replication factor one. They can be adjusted in `kafka/docker/docker-compose.yml` when a later task requires it.

## List Topics

From `kafka/docker`:

```bash
docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 --list
```

Expected ASSMS business topics:

- `job-created`
- `job-assigned`
- `job-status-changed`

From the repository root in a Bash-compatible shell, `./kafka/scripts/list-topics.sh` runs the same check.

## Environment Variables

Applications running directly on the developer machine will use:

```text
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
```

Containers attached to the Compose network use the internal listener:

```text
KAFKA_BOOTSTRAP_SERVERS=kafka:29092
```

Copy the non-secret examples from the root `.env.example` into an untracked local `.env` only when a later application-integration task requires them.

## Producer and Consumer Smoke Test

Open two terminals after Kafka is healthy.

In terminal 1, start a consumer from `kafka/docker`:

```bash
docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:29092 --topic job-created --group assms-smoke-test --from-beginning
```

In terminal 2, start a producer:

```bash
docker compose exec kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:29092 --topic job-created
```

Enter this development-only message and press Enter:

```json
{"test":"ASSMS Kafka smoke test"}
```

Terminal 1 should display the same JSON. Press Ctrl+C in both terminals when finished. This test message is not a production event schema.

## Topic Ownership

| Topic | Producer | Consumers |
| --- | --- | --- |
| `job-created` | Job Service | Dispatch Service, Reporting Service |
| `job-assigned` | Dispatch Service | Job Service, Reporting Service |
| `job-status-changed` | Job Service | Reporting Service |

This table documents intended ownership only. No application producer or consumer is implemented by this task.

## Consumer Groups

Each service uses an independent consumer group so every required service receives its own copy of an event:

| Topic | Service | Suggested consumer group |
| --- | --- | --- |
| `job-created` | Dispatch Service | `assms-dispatch-job-created` |
| `job-created` | Reporting Service | `assms-reporting-job-created` |
| `job-assigned` | Job Service | `assms-job-job-assigned` |
| `job-assigned` | Reporting Service | `assms-reporting-job-assigned` |
| `job-status-changed` | Reporting Service | `assms-reporting-job-status-changed` |

Dispatch and Reporting must not share a group for `job-created`; both need the event independently. These names are configuration guidance for later application-integration tasks.

## Troubleshooting

- Check port usage if Kafka cannot bind to `localhost:9092`.
- If Windows reserves port `9092`, set `KAFKA_HOST_PORT` to an available port before running Compose and use the same port in `KAFKA_BOOTSTRAP_SERVERS`. The default remains `9092`.
- Run `docker compose logs kafka` to inspect broker startup.
- Run `docker compose logs topic-init` if the expected topics are missing.
- Use `docker compose run --rm topic-init` to rerun idempotent topic creation.
- If old local data causes an intentional reset to be necessary, stop the stack and explicitly remove its named volume with `docker compose down --volumes`.

## Future Azure Configuration

ASSMS-17 owns the future Azure Kafka VM infrastructure. Backend Azure VMs will eventually use configuration conceptually like:

```text
KAFKA_BOOTSTRAP_SERVERS=<Kafka-VM-private-IP>:9092
```

The address must remain configurable and must not be hard-coded. Azure service VMs should reach Kafka through the private ASSMS VNet. Kafka port `9092` must not be exposed publicly.
