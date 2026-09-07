#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="${script_directory}/../docker/docker-compose.yml"

docker compose -f "${compose_file}" up -d
docker compose -f "${compose_file}" ps
