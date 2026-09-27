# ASSMS Kafka Observability & Event Baseline Specification

## 1. Overview

This document specifies the observability, metrics, and logging standards for Apache Kafka messaging across all ASSMS microservices (`JobService`, `DispatchService`, `ReportingService`).

Sprint 3 relies on three core Kafka topic event flows:
- **`job-created`**: Produced by Job Service $\rightarrow$ Consumed by Dispatch Service & Reporting Service.
- **`job-assigned`**: Produced by Dispatch Service (Outbox Pattern) $\rightarrow$ Consumed by Job Service & Reporting Service.
- **`job-status-changed`**: Produced by Job Service $\rightarrow$ Consumed by Reporting Service.

---

## 2. Broker Level Metrics (`kafka-exporter`)

The staging Kafka broker runs on VM `10.20.2.4:9092`. The `kafka-exporter` container exposes Prometheus metrics on port `9308`.

| Metric Name | Type | Description | Alert Threshold |
| --- | --- | --- | --- |
| `kafka_consumergroup_lag` | Gauge | Unprocessed message count per topic & consumer group. | `lag > 10` for > 5m |
| `kafka_topic_partition_current_offset` | Counter | Total published message offset count per partition. | N/A (Rate monitoring) |
| `kafka_broker_info` | Gauge | Broker availability status (1 = UP, 0 = DOWN). | `< 1` |

### Staging Consumer Groups Monitored:
- `assms-dispatch-job-created`
- `assms-reporting-job-created`
- `assms-job-job-assigned`
- `assms-reporting-job-assigned`

---

## 3. Producer & Outbox Metrics Standard

Dispatch Service uses an **Outbox Pattern** to ensure transactional atomicity between MySQL database writes and Kafka publishing.

### Required Custom Application Metrics:

```csharp
// Pending outbox records waiting in MySQL
public static readonly Gauge OutboxPendingGauge = Metrics.CreateGauge(
    "assms_dispatch_outbox_pending_count",
    "Number of unsent outbox events waiting in database queue");

// Successful outbox message publication count
public static readonly Counter OutboxPublishedCounter = Metrics.CreateCounter(
    "assms_dispatch_outbox_published_total",
    "Total outbox events published to Kafka",
    new CounterConfiguration { LabelNames = new[] { "topic" } });

// Failed outbox message publication attempts
public static readonly Counter OutboxFailedCounter = Metrics.CreateCounter(
    "assms_dispatch_outbox_failed_total",
    "Total outbox publication failures",
    new CounterConfiguration { LabelNames = new[] { "topic", "error_type" } });
```

---

## 4. Consumer Metrics Standard

All event consumer background services must emit processing metrics using `prometheus-net`:

```csharp
public static readonly Counter EventsConsumedCounter = Metrics.CreateCounter(
    "assms_kafka_events_consumed_total",
    "Total Kafka events processed by consumer",
    new CounterConfiguration { LabelNames = new[] { "topic", "consumer_group", "status" } });
```

### Usage Pattern:
- On successful processing:
  `EventsConsumedCounter.WithLabels("job-created", "assms-dispatch-job-created", "success").Inc();`
- On error / exception:
  `EventsConsumedCounter.WithLabels("job-created", "assms-dispatch-job-created", "failed").Inc();`

---

## 5. Structured JSON Logging Convention

All Kafka producers and consumers MUST use structured parameter logging to enable trace correlation across microservices.

### Log Parameter Rules:
- **`Topic`**: Exact Kafka topic name.
- **`JobId`**: Functional job ID (e.g. `JOB-1ARDN1`).
- **`ConsumerGroup`**: Active consumer group ID.
- **`TraceId`**: W3C / Activity trace identifier.

### Producer Example:
```csharp
_logger.LogInformation(
    "Published Kafka event to Topic={Topic} for JobId={JobId} with OutboxId={OutboxId}",
    topic, jobId, outboxId);
```

### Consumer Example:
```csharp
_logger.LogInformation(
    "Kafka event processed successfully: Topic={Topic}, JobId={JobId}, ConsumerGroup={ConsumerGroup}",
    topic, jobId, consumerGroup);
```
