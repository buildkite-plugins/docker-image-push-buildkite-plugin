#!/bin/bash

setup_gar_environment() {
  local project="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_GAR_PROJECT:-}"
  local region="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_GAR_REGION:-us}"

  if ! command_exists gcloud; then
    log_error "Google Cloud SDK is required for GAR provider"
    exit 1
  fi

  if [[ -z "$project" ]]; then
    log_error "GAR project is required"
    exit 1
  fi

  log_info "Using GAR project: $project"
  log_info "Using GAR region: $region"

  # Determine correct registry host based on region value.
  # If the region ends with ".pkg.dev" we assume Google Artifact Registry
  # (e.g. europe-west10-docker.pkg.dev). Otherwise we default to Container
  # Registry (e.g. eu.gar.io).
  local registry_host
  if [[ "${region}" =~ \.pkg\.dev$ ]]; then
    registry_host="${region}"
  else
    registry_host="${region}.gar.io"
  fi

  log_info "Authenticating with registry: ${registry_host}"
  if ! gcloud auth configure-docker "${registry_host}" --quiet; then
    log_error "Failed to authenticate with ${registry_host}"
    exit 1
  fi

  log_success "Successfully authenticated with ${registry_host}"

  local repository="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_GAR_REPOSITORY:-${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}}"
  local tag="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG:-latest}"

  export DOCKER_PUSH_REMOTE_IMAGE="${registry_host}/${project}/${repository}/${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}:${tag}"
}
