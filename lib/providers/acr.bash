#!/bin/bash

# Azure Container Registry provider for Docker push plugin

setup_acr_environment() {
  local registry_url_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ACR_REGISTRY_URL:-}"
  local client_id_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ACR_CLIENT_ID:-}"
  local client_secret_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ACR_CLIENT_SECRET:-}"

  # Validate required parameters
  if [[ -z "$registry_url_raw" ]]; then
    log_error "ACR registry URL is required"
    log_info "Set it via the 'registry-url' parameter in acr configuration"
    exit 1
  fi

  if [[ -z "$client_id_raw" ]]; then
    log_error "ACR client ID is required"
    log_info "Set it via the 'client-id' parameter in acr configuration"
    exit 1
  fi

  if [[ -z "$client_secret_raw" ]]; then
    log_error "ACR client secret is required"
    log_info "Set it via the 'client-secret' parameter in acr configuration"
    exit 1
  fi

  # Process environment variable references in parameters
  local registry_url
  registry_url=$(expand_env_var "$registry_url_raw" "registry-url")

  local client_id
  client_id=$(expand_env_var "$client_id_raw" "client-id")

  local client_secret
  client_secret=$(expand_env_var "$client_secret_raw" "client-secret")

  # Clean up registry URL (remove protocol if present)
  registry_url="${registry_url#https://}"
  registry_url="${registry_url#http://}"

  export DOCKER_PUSH_ACR_REGISTRY_URL="$registry_url"

  log_info "ACR registry URL: $registry_url"
  log_info "ACR client ID: $client_id"

  log_info "Authenticating with Azure Container Registry..."
  if docker login "$registry_url" -u "$client_id" -p "$client_secret"; then
    log_success "Successfully authenticated with ACR"
  else
    log_error "Failed to authenticate with ACR"
    log_info "Verify your client ID and client secret are correct"
    log_info "Ensure the registry URL is accessible and the service principal has appropriate permissions"
    exit 1
  fi

  local repository="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ACR_REPOSITORY:-${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}}"
  local tag="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG:-latest}"
  export DOCKER_PUSH_REMOTE_IMAGE="${registry_url}/${repository}:${tag}"
}
