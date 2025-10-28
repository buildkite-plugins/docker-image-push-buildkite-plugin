#!/bin/bash

# Namespace registry provider for Docker image push plugin

DEFAULT_NAMESPACE_REGISTRY="nscr.io"
DEFAULT_NAMESPACE_AUDIENCE="federation.namespaceapis.com"
DEFAULT_NAMESPACE_NSC_BIN="/root/.ns/bin/nsc"

setup_namespace_environment() {
  local tenant_id="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_TENANT_ID:-}"
  local registry_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_REGISTRY:-$DEFAULT_NAMESPACE_REGISTRY}"
  local auth_method="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_AUTH_METHOD:-buildkite-oidc}"
  local audience="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_AUDIENCE:-$DEFAULT_NAMESPACE_AUDIENCE}"
  local nsc_bin="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_NSC_BINARY:-$DEFAULT_NAMESPACE_NSC_BIN}"

  if [[ -z "$tenant_id" ]]; then
    log_error "Namespace tenant-id is required"
    log_info "Set it via the namespace.tenant-id configuration option"
    exit 1
  fi

  # Normalise registry host (strip scheme/trailing slashes)
  local registry="${registry_raw#https://}"
  registry="${registry#http://}"
  registry="${registry%/}"
  if [[ -z "$registry" ]]; then
    registry="$DEFAULT_NAMESPACE_REGISTRY"
  fi

  # Locate Namespace CLI
  if [[ ! -x "$nsc_bin" ]]; then
    if command_exists nsc; then
      nsc_bin="$(command -v nsc)"
    else
      log_error "Namespace CLI (nsc) not found at ${nsc_bin}"
      log_info "Install the Namespace CLI or set namespace.nsc-binary"
      exit 1
    fi
  fi

  local tenant_slug="$tenant_id"
  if [[ "$tenant_slug" == tenant_* ]]; then
    tenant_slug="${tenant_slug#tenant_}"
  fi

  log_info "Namespace registry host: ${registry}"
  log_info "Namespace tenant: ${tenant_id}"
  log_info "Namespace registry slug: ${tenant_slug}"
  log_info "Namespace auth method: ${auth_method}"

  case "$auth_method" in
  buildkite-oidc)
    namespace_auth_with_oidc "$nsc_bin" "$tenant_id" "$audience"
    ;;
  aws-cognito)
    namespace_auth_with_cognito "$nsc_bin" "$tenant_id"
    ;;
  *)
    log_error "Unsupported Namespace auth method: ${auth_method}"
    log_info "Supported methods: buildkite-oidc, aws-cognito"
    exit 1
    ;;
  esac

  log_info "Logging into Namespace registry"
  if ! "$nsc_bin" docker login; then
    log_error "Failed to login to Namespace registry"
    exit 1
  fi

  local tag="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG:-latest}"
  local image_name="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}"
  local remote_image="${registry}/${tenant_slug}/${image_name}:${tag}"
  export DOCKER_PUSH_REMOTE_IMAGE="$remote_image"

  log_info "Namespace remote image: ${remote_image}"
}

namespace_auth_with_oidc() {
  local nsc_bin="$1"
  local tenant_id="$2"
  local audience="$3"

  if ! command_exists buildkite-agent; then
    log_error "buildkite-agent is required for Namespace OIDC authentication"
    exit 1
  fi

  log_info "Requesting Namespace OIDC token for audience: ${audience}"
  local oidc_token
  if ! oidc_token="$(buildkite-agent oidc request-token --audience "$audience" --lifetime 300)"; then
    log_error "Failed to request Buildkite OIDC token for Namespace"
    exit 1
  fi

  if ! "$nsc_bin" auth exchange-oidc-token --token "$oidc_token" --tenant_id "$tenant_id"; then
    log_error "Failed to exchange OIDC token with Namespace"
    exit 1
  fi

  log_success "Authenticated with Namespace using Buildkite OIDC"
}

namespace_auth_with_cognito() {
  local nsc_bin="$1"
  local tenant_id="$2"
  local region="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_AWS_COGNITO_REGION:-}"
  local identity_pool="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_AWS_COGNITO_IDENTITY_POOL:-}"

  if [[ -z "$region" ]]; then
    log_error "Namespace aws-cognito.region is required when auth-method is aws-cognito"
    exit 1
  fi

  if [[ -z "$identity_pool" ]]; then
    log_error "Namespace aws-cognito.identity-pool is required when auth-method is aws-cognito"
    exit 1
  fi

  log_info "Authenticating with Namespace using AWS Cognito federation"
  if ! "$nsc_bin" auth exchange-aws-cognito-token --aws_region "$region" --identity_pool "$identity_pool" --tenant_id "$tenant_id"; then
    log_error "Failed to exchange Cognito token with Namespace"
    exit 1
  fi

  log_success "Authenticated with Namespace using AWS Cognito"
}
