#!/bin/bash

# Azure Container Registry provider for Docker push plugin

setup_acr_environment() {
  local registry_url_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ACR_REGISTRY_URL:-}"
  local acr_login="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ACR_ACR_LOGIN:-false}"

  # Validate registry URL is always required
  if [[ -z "$registry_url_raw" ]]; then
    log_error "ACR registry URL is required"
    log_info "Set it via the 'registry-url' parameter in acr configuration"
    exit 1
  fi

  # Process environment variable reference for registry URL
  local registry_url
  registry_url=$(expand_env_var "$registry_url_raw" "registry-url")

  # Clean up registry URL (remove protocol if present)
  registry_url="${registry_url#https://}"
  registry_url="${registry_url#http://}"

  export DOCKER_PUSH_ACR_REGISTRY_URL="$registry_url"

  log_info "ACR registry URL: $registry_url"

  if [[ "$acr_login" =~ ^(true|1)$ ]]; then
    # Use Azure CLI authentication
    if ! command_exists az; then
      log_error "Azure CLI (az) is required when acr-login is enabled"
      log_info "Install the Azure CLI or use service principal authentication instead"
      exit 1
    fi

    # Extract registry name from URL (remove .azurecr.io suffix)
    local registry_name="${registry_url%.azurecr.io}"

    log_info "Authenticating with Azure Container Registry using Azure CLI..."
    if az acr login --name "$registry_name"; then
      log_success "Successfully authenticated with ACR using Azure CLI"
    else
      log_error "Failed to authenticate with ACR using Azure CLI"
      log_info "Ensure you are logged in to Azure (az login) and have access to the registry"
      exit 1
    fi
  else
    # Use service principal authentication
    local client_id_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ACR_CLIENT_ID:-}"
    local client_secret_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ACR_CLIENT_SECRET:-}"

    if [[ -z "$client_id_raw" ]]; then
      log_error "ACR client ID is required"
      log_info "Set it via the 'client-id' parameter in acr configuration, or use 'acr-login: true' for Azure CLI authentication"
      exit 1
    fi

    if [[ -z "$client_secret_raw" ]]; then
      log_error "ACR client secret is required"
      log_info "Set it via the 'client-secret' parameter in acr configuration, or use 'acr-login: true' for Azure CLI authentication"
      exit 1
    fi

    local client_id
    client_id=$(expand_env_var "$client_id_raw" "client-id")

    local client_secret
    client_secret=$(expand_env_var "$client_secret_raw" "client-secret")

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
  fi

  local repository="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ACR_REPOSITORY:-${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}}"
  local tag="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG:-latest}"
  export DOCKER_PUSH_REMOTE_IMAGE="${registry_url}/${repository}:${tag}"
}
