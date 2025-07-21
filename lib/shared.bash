#!/bin/bash

# Shared utility functions for the Docker push plugin

set -euo pipefail

log_info() {
  echo "[INFO]: $*"
}

log_success() {
  echo "[SUCCESS]: $*"
}

log_warning() {
  echo "[WARNING]: $*"
}

log_error() {
  echo "[ERROR]: $*" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

unknown_provider() {
  log_error "Unknown provider: $1"
  exit 1
}

check_dependencies() {
  local missing_deps=()

  if ! command_exists docker; then
    missing_deps+=("docker")
  fi

  case "${BUILDKITE_PLUGIN_DOCKER_PUSH_PROVIDER}" in
    ecr)
      if ! command_exists aws; then
        missing_deps+=("aws")
      fi
      ;;
    gar)
      if ! command_exists gcloud; then
        missing_deps+=("gcloud")
      fi
      ;;
  esac

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing_deps[*]}"
    log_error "Please install the missing dependencies and try again."
    exit 1
  fi
}



push_image() {
  local image="$1"

  log_info "Pushing image: $image"
  if docker push "$image"; then
    log_success "Successfully pushed image"
    return 0
  else
    log_error "Failed to push image"
    return 1
  fi
}

tag_image() {
  local source_image="$1"
  local target_image="$2"

  log_info "Tagging image $source_image -> $target_image"
  if docker tag "$source_image" "$target_image"; then
    log_success "Image tagged successfully"
    return 0
  else
    log_error "Failed to tag image"
    return 1
  fi
}
