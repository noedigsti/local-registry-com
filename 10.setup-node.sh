#!/bin/bash

# Function to process a single worker
process_worker() {
  local WORKER_NAME=$1

  echo "Worker name set to: $WORKER_NAME"

  DOCKER_CONTAINER_CURRENT=$(docker ps -a --filter "name=^/$WORKER_NAME$" -q)

  echo "Looking for containers matching pattern: wslkindmultinodes with name containing: $WORKER_NAME"
  echo "Found container ID: $DOCKER_CONTAINER_CURRENT"

  if [ -z "$DOCKER_CONTAINER_CURRENT" ]; then
    echo "No container found for name pattern: wslkindmultinodes with name containing: $WORKER_NAME"
    return 1
  fi

  # Copy the rootCA.crt to the container
  docker cp out/rootCA.crt $DOCKER_CONTAINER_CURRENT:/usr/share/ca-certificates/

  docker exec -it $DOCKER_CONTAINER_CURRENT bash -c " \
    echo 'rootCA.crt' | tee -a /etc/ca-certificates.conf && \
    apt update -qq && \
    apt install -y mkcert nano && \
    mkcert -install && \
    update-ca-certificates && \
    curl -v https://local.registry.com:32555 && \
    mkdir -p /etc/containerd/certs.d/https://local.registry.com:32555 && \
    echo 'server = \"https://local.registry.com:32555\"' > /etc/containerd/certs.d/https://local.registry.com:32555/hosts.toml && \
    echo '[host.\"https://local.registry.com:32555\"]' >> /etc/containerd/certs.d/https://local.registry.com:32555/hosts.toml && \
    echo '  capabilities = [\"pull\", \"resolve\"]' >> /etc/containerd/certs.d/https://local.registry.com:32555/hosts.toml && \
    echo '  skip_verify = true' >> /etc/containerd/certs.d/https://local.registry.com:32555/hosts.toml && \
    echo '[plugins.\"io.containerd.grpc.v1.cri\".registry]' >> /etc/containerd/config.toml && \
    echo '  config_path = \"/etc/containerd/certs.d\"' >> /etc/containerd/config.toml && \
    systemctl restart containerd && \
    systemctl status containerd
  "

  return 0
}

# List of worker names
WORKER_NAMES=(
  # "wslkindmultinodes-control-plane"
  "wslkindmultinodes-worker"
  "wslkindmultinodes-worker2"
  "wslkindmultinodes-worker3"
)

# Iterate over each worker name and process it
for WORKER_NAME in "${WORKER_NAMES[@]}"; do
  process_worker "$WORKER_NAME"
done
