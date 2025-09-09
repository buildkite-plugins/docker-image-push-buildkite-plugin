#!/bin/bash

# Buildkite Packages Container Registry provider for Docker push plugin

setup_buildkite_environment() {
  local org_slug="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_BUILDKITE_ORG_SLUG:-}"
  local registry_slug="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_BUILDKITE_REGISTRY_SLUG:-}"
  local auth_method="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_BUILDKITE_AUTH_METHOD:-api-token}"

  # Auto-detect organization slug from environment if not provided
  if [[ -z "$org_slug" ]]; then
    org_slug="${BUILDKITE_ORGANIZATION_SLUG:-}"
    if [[ -z "$org_slug" ]]; then
      log_error "Buildkite organization slug is required. Set it in configuration or BUILDKITE_ORGANIZATION_SLUG environment variable."
      exit 1
    fi
    log_info "Using organization slug from environment: $org_slug"
  fi

  # Default registry slug to image name if not provided
  if [[ -z "$registry_slug" ]]; then
    registry_slug="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}"
    log_info "Registry slug defaulting to image name: $registry_slug"
  fi

  local registry_url="packages.buildkite.com/${org_slug}/${registry_slug}"
  export DOCKER_PUSH_BUILDKITE_REGISTRY_URL="$registry_url"

  log_info "Buildkite registry URL: $registry_url"
  log_info "Authentication method: $auth_method"

  # Authenticate with registry based on method
  case "$auth_method" in
  api-token)
    authenticate_with_api_token "$registry_url"
    ;;
  oidc)
    authenticate_with_oidc "$registry_url"
    ;;
  *)
    log_error "Unsupported authentication method: $auth_method"
    log_info "Supported methods: api-token, oidc"
    exit 1
    ;;
  esac

  local tag="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG:-latest}"
  export DOCKER_PUSH_REMOTE_IMAGE="${registry_url}/${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}:${tag}"
}

authenticate_with_api_token() {
  local registry_url="$1"
  local api_token_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_BUILDKITE_API_TOKEN:-}"

  local api_token
  # Restrict environment variable expansion to safe, allow listed variables only
  # shellcheck disable=SC2016
  case "${api_token_raw}" in
  '$CONTAINER_PACKAGE_REGISTRY_TOKEN' | '$BUILDKITE_API_TOKEN' | '$BUILDKITE_PLUGIN_'*)
    local var_name="${api_token_raw#$}"
    api_token="${!var_name}"
    ;;
  *)
    api_token="${api_token_raw}"
    ;;
  esac

  # Fallback to environment variable for backward compatibility
  if [[ -z "$api_token" ]]; then
    api_token="${BUILDKITE_API_TOKEN:-}"
  fi

  if [[ -z "$api_token" ]]; then
    log_error "API token is required for api-token authentication"
    log_info "Set it via the 'api-token' parameter or BUILDKITE_API_TOKEN environment variable"
    log_info "Ensure your token has Read Packages and Write Packages scopes"
    exit 1
  fi

  log_info "Authenticating with Buildkite Packages using API token..."
  if docker login "$registry_url" -u buildkite -p "$api_token"; then
    log_success "Successfully authenticated with Buildkite Packages"
  else
    log_error "Failed to authenticate with Buildkite Packages"
    log_info "Verify your API token has Read Packages and Write Packages scopes"
    exit 1
  fi
}

authenticate_with_oidc() {
  local registry_url="$1"
  local audience="https://${registry_url}"

  log_info "Requesting OIDC token for audience: $audience"
  log_info "Authenticating with Buildkite Packages using OIDC..."

  if buildkite-agent oidc request-token --audience "$audience" --lifetime 300 | docker login "$registry_url" --username buildkite --password-stdin; then
    log_success "Successfully authenticated with Buildkite Packages using OIDC"
  else
    log_error "Failed to authenticate with Buildkite Packages using OIDC"
    log_info "Verify your pipeline has access to the registry and meets OIDC policy requirements"
    exit 1
  fi
}
