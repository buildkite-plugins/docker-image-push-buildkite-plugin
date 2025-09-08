#!/bin/bash

setup_artifactory_environment() {
  local registry_url_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_REGISTRY_URL:-}"
  local username_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_USERNAME:-}"
  local identity_token_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_IDENTITY_TOKEN:-}"

  # Validate required parameters
  if [[ -z "$registry_url_raw" ]]; then
    log_error "Artifactory registry URL is required"
    log_info "Set it via the 'registry-url' parameter in artifactory configuration"
    exit 1
  fi

  if [[ -z "$username_raw" ]]; then
    log_error "Artifactory username is required"
    log_info "Set it via the 'username' parameter in artifactory configuration"
    exit 1
  fi

  if [[ -z "$identity_token_raw" ]]; then
    log_error "Artifactory identity token is required"
    log_info "Set it via the 'identity-token' parameter in artifactory configuration"
    exit 1
  fi

  # Process environment variable references in parameters
  local registry_url
  registry_url=$(expand_env_var "$registry_url_raw" "registry-url")

  local username
  username=$(expand_env_var "$username_raw" "username")

  local identity_token
  identity_token=$(expand_env_var "$identity_token_raw" "identity-token")

  # Clean up registry URL (remove protocol if present)
  registry_url="${registry_url#https://}"
  registry_url="${registry_url#http://}"

  export DOCKER_PUSH_ARTIFACTORY_REGISTRY_URL="$registry_url"

  log_info "Artifactory registry URL: $registry_url"
  log_info "Artifactory username: $username"

  log_info "Authenticating with Artifactory Docker registry..."
  if docker login "$registry_url" -u "$username" -p "$identity_token"; then
    log_success "Successfully authenticated with Artifactory"
  else
    log_error "Failed to authenticate with Artifactory"
    log_info "Verify your username and identity token are correct"
    log_info "Ensure the registry URL is accessible and supports Docker registry API"
    exit 1
  fi

  local repository="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_REPOSITORY:-${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}}"
  local tag="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG:-latest}"
  export DOCKER_PUSH_REMOTE_IMAGE="${registry_url}/${repository}/${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}:${tag}"
}
