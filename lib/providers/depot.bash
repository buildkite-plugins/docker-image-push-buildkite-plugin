#!/bin/bash

# depot.dev provider for Docker push plugin

setup_depot_environment() {
  # Read raw config values
  local access_token_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_DEPOT_ACCESS_TOKEN:-}"
  local project_id_raw="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_DEPOT_PROJECT_ID:-}"
  local use_oidc="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_DEPOT_OIDC:-false}"
  
  local project_id
  # Restrict environment variable expansion to safe, allow listed variables only
  # shellcheck disable=SC2016
  case "${project_id_raw}" in
    '$DEPOT_PROJECT_ID'|'$DEPOT_DEV_PROJECT_ID'|'$BUILDKITE_PLUGIN_'*)
      local var_name="${project_id_raw#$}"
      project_id="${!var_name}"
      ;;
    *)
      project_id="${project_id_raw}"
      ;;
  esac
  
  project_id="${project_id:-${DEPOT_DEV_PROJECT_ID:-}}"

  if [[ -z "$project_id" ]]; then
    log_error "depot project-id is required"
    exit 1
  fi

  log_info "Setting up Depot build environment"

  if [[ "${use_oidc}" == "true" ]]; then
    # For OIDC, we don't export DEPOT_TOKEN - depot CLI will handle OIDC flow automatically
    # The Depot CLI will detect the Buildkite environment and retrieve OIDC tokens as needed
    export DEPOT_PROJECT_ID="${project_id}"
    log_info "Depot CLI will use OIDC authentication automatically"
  else
    local access_token
    # Restrict environment variable expansion to safe, allow listed variables only
    # shellcheck disable=SC2016
    case "${access_token_raw}" in
      '$DEPOT_TOKEN'|'$DEPOT_DEV_TOKEN'|'$BUILDKITE_PLUGIN_'*)
        local var_name="${access_token_raw#$}"
        access_token="${!var_name}"
        ;;
      *)
        access_token="${access_token_raw}"
        ;;
    esac
    
    access_token="${access_token:-${DEPOT_DEV_TOKEN:-}}"

    if [[ -z "$access_token" ]]; then
      log_error "depot access-token is required when not using OIDC"
      log_error "Either provide access-token or set oidc: true"
      exit 1
    fi

    log_info "Using token-based authentication with Depot"
    export DEPOT_TOKEN="${access_token}"
    export DEPOT_PROJECT_ID="${project_id}"
  fi
}

build_and_push_depot_image() {
  local image_name="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE:-}"
  local tag="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG:-latest}"
  local project_id="${DEPOT_PROJECT_ID:-}"
  local context="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_DEPOT_CONTEXT:-.}"

  if [[ -z "${image_name}" ]]; then
    log_error "Image name is required for depot build."
    exit 1
  fi

  if [[ -z "${project_id}" ]]; then
    log_error "Project ID is required for depot build."
    exit 1
  fi

  # Build and save image using depot build --save
  local build_args=()
  build_args+=("--save")
  build_args+=("--save-tag=${tag}")
  build_args+=("--project=${project_id}")
  
  
  # Add platform if specified
  local platform="${BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_DEPOT_PLATFORM:-}"
  if [[ -n "${platform}" ]]; then
    build_args+=("--platform=${platform}")
  fi
  
  local full_image="${image_name}:${tag}"
  build_args+=("--tag=${full_image}")
  
  # Validate build context
  if [[ ! -d "${context}" ]]; then
    log_error "Build context '${context}' does not exist or is not a directory"
    log_error "Current working directory: $(pwd)"
    log_error "Available directories: $(ls -la 2>/dev/null || echo 'none')"
    return 1
  fi
  
  log_info "Building and pushing image: ${full_image} from context: ${context}"
  log_info "Depot build command: depot build ${build_args[*]} -- ${context}"
  
  if depot build "${build_args[@]}" -- "${context}"; then
    return 0
  else
    log_error "Failed to build image"
    return 1
  fi
}