#!/bin/bash

# AWS ECR provider for Docker push plugin

setup_ecr_environment() {
  local region="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ECR_REGION:-}"
  local account_id="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ECR_ACCOUNT_ID:-}"
  local registry_url="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ECR_REGISTRY_URL:-}"

  if ! command_exists aws; then
    log_error "AWS CLI is required for ECR provider"
    exit 1
  fi

  if [[ -z "$region" ]]; then
    region=$(aws configure get region 2>/dev/null || echo "us-east-1")
    log_info "Using AWS region: $region"
  fi
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ECR_REGION="$region"

  if [[ -z "$account_id" ]]; then
    log_info "Auto-detecting AWS account ID..."
    account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [[ -z "$account_id" ]]; then
      log_error "Failed to auto-detect AWS account ID. Please provide it in the configuration."
      exit 1
    fi
    log_info "Using AWS account ID: $account_id"
  fi
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ECR_ACCOUNT_ID="$account_id"

  if [[ -z "$registry_url" ]]; then
    registry_url="${account_id}.dkr.ecr.${region}.amazonaws.com"
  fi
  export DOCKER_PUSH_ECR_REGISTRY_URL="$registry_url"

  log_info "ECR registry URL: $registry_url"

  log_info "Authenticating with ECR..."
  if ! aws ecr get-login-password --region "${region}" | docker login --username AWS --password-stdin "${registry_url}"; then
    log_error "Failed to authenticate with ECR"
    exit 1
  fi

  log_success "Successfully authenticated with ECR"

    local tag="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG:-latest}"
  export DOCKER_PUSH_REMOTE_IMAGE="${registry_url}/${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE}:${tag}"
}
