#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="${script_directory}/../docker/docker-compose.yml"

docker compose -f "${compose_file}" exec kafka \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:29092 \
  --list
