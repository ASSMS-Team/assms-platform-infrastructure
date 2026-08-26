#!/usr/bin/env bash

set -euo pipefail

bootstrap_servers="${KAFKA_BOOTSTRAP_SERVERS:-kafka:29092}"
partitions="${KAFKA_TOPIC_PARTITIONS:-1}"
replication_factor="${KAFKA_TOPIC_REPLICATION_FACTOR:-1}"
kafka_topics="/opt/kafka/bin/kafka-topics.sh"

echo "Waiting for Kafka at ${bootstrap_servers}..."
for attempt in $(seq 1 30); do
  if "${kafka_topics}" --bootstrap-server "${bootstrap_servers}" --list >/dev/null 2>&1; then
    break
  fi

  if [ "${attempt}" -eq 30 ]; then
    echo "Kafka did not become ready after 30 attempts." >&2
    exit 1
  fi

  sleep 2
done

for topic in job-created job-assigned job-status-changed; do
  "${kafka_topics}" \
    --bootstrap-server "${bootstrap_servers}" \
    --create \
    --if-not-exists \
    --topic "${topic}" \
    --partitions "${partitions}" \
    --replication-factor "${replication_factor}"
done

echo "ASSMS Kafka topics are ready."
