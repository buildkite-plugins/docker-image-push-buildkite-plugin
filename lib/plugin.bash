#!/bin/bash

# Ensure a stable env-var prefix; allow caller to override
PLUGIN_PREFIX="${PLUGIN_PREFIX:-DOCKER_CACHE}"

# Initialise default config values (exported env-vars)
plugin_init_defaults() {
  export BUILDKITE_PLUGIN_DOCKER_CACHE_SAVE="${BUILDKITE_PLUGIN_DOCKER_CACHE_SAVE:-true}"
  export BUILDKITE_PLUGIN_DOCKER_CACHE_RESTORE="${BUILDKITE_PLUGIN_DOCKER_CACHE_RESTORE:-true}"
  export BUILDKITE_PLUGIN_DOCKER_CACHE_TAG="${BUILDKITE_PLUGIN_DOCKER_CACHE_TAG:-cache}"
  export BUILDKITE_PLUGIN_DOCKER_CACHE_VERBOSE="${BUILDKITE_PLUGIN_DOCKER_CACHE_VERBOSE:-false}"
}

# Load shared utilities
# shellcheck source=lib/shared.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shared.bash"

# Export default configuration values so that later functions have them even
# when the user omits optional plugin keys (e.g. TAG)
plugin_init_defaults

# Load provider implementations
# shellcheck source=lib/providers/acr.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/providers/acr.bash"
# shellcheck source=lib/providers/ecr.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/providers/ecr.bash"
# shellcheck source=lib/providers/gar.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/providers/gar.bash"
# shellcheck source=lib/providers/dockerhub.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/providers/dockerhub.bash"

plugin_read_config() {
  export BUILDKITE_PLUGIN_DOCKER_CACHE_SAVE="${BUILDKITE_PLUGIN_DOCKER_CACHE_SAVE:-true}"
  export BUILDKITE_PLUGIN_DOCKER_CACHE_RESTORE="${BUILDKITE_PLUGIN_DOCKER_CACHE_RESTORE:-true}"
  export BUILDKITE_PLUGIN_DOCKER_CACHE_TAG="${BUILDKITE_PLUGIN_DOCKER_CACHE_TAG:-cache}"
  export BUILDKITE_PLUGIN_DOCKER_CACHE_VERBOSE="${BUILDKITE_PLUGIN_DOCKER_CACHE_VERBOSE:-false}"
}

setup_provider_environment() {
  local provider="$1"

  case "$provider" in
    acr)
      setup_acr_environment
      ;;
    ecr)
      setup_ecr_environment
      ;;
    gar)
      setup_gar_environment
      ;;
    dockerhub)
      setup_dockerhub_environment
      ;;
    *)
      unknown_provider "$provider"
      ;;
  esac
}

generate_cache_key() {
  local cache_key_input="${BUILDKITE_PLUGIN_DOCKER_CACHE_CACHE_KEY:-}"

  if [[ -n "$cache_key_input" ]]; then
    # User provided explicit cache key
    if [[ "$cache_key_input" == *"/"* ]]; then
      # Treat as file path(s)
      echo "$cache_key_input" | tr ',' '\n' | while read -r file; do
        if [[ -f "$file" ]]; then
          sha1sum "$file"
        else
          log_warning "Cache key file not found $file"
        fi
      done | sha1sum | cut -d' ' -f1
    else
      # Treat as string
      echo -n "$cache_key_input" | sha1sum | cut -d' ' -f1
    fi
  else
    # Auto-generate cache key from common files
    local key_components=""

    # Check for common dependency files
    for file in Dockerfile package.json yarn.lock requirements.txt Gemfile.lock composer.lock go.mod; do
      if [[ -f "$file" ]]; then
        key_components="${key_components}$(sha1sum "$file")"
      fi
    done

    # Include git commit if available
    if [[ -n "${BUILDKITE_COMMIT:-}" ]]; then
      key_components="${key_components}${BUILDKITE_COMMIT}"
    fi

    # Generate final key
    if [[ -n "$key_components" ]]; then
      echo -n "$key_components" | sha1sum | cut -d' ' -f1
    else
      # Fallback to timestamp-based key
      echo -n "$(date +%Y%m%d)" | sha1sum | cut -d' ' -f1
    fi
  fi
}

restore_cache() {
  local provider="$1"
  local cache_key="$2"

  if [[ "${BUILDKITE_PLUGIN_DOCKER_CACHE_RESTORE}" != "true" ]]; then
    log_info "Cache restore disabled, skipping"
    return 0
  fi

  log_info "Restoring cache from $provider"

  case "$provider" in
    acr)
      restore_acr_cache "$cache_key"
      ;;
    ecr)
      restore_ecr_cache "$cache_key"
      ;;
    gar)
      restore_gar_cache "$cache_key"
      ;;
    dockerhub)
      restore_dockerhub_cache "$cache_key"
      ;;
    *)
      unknown_provider "$provider"
      ;;
  esac
}

save_cache() {
  local provider="$1"
  local cache_key="$2"

  if [[ "${BUILDKITE_PLUGIN_DOCKER_CACHE_SAVE}" != "true" ]]; then
    log_info "Cache save disabled, skipping"
    return 0
  fi

  log_info "Saving cache to $provider"

  case "$provider" in
    acr)
      save_acr_cache "$cache_key"
      ;;
    ecr)
      save_ecr_cache "$cache_key"
      ;;
    gar)
      save_gar_cache "$cache_key"
      ;;
    dockerhub)
      save_dockerhub_cache "$cache_key"
      ;;
    *)
      unknown_provider "$provider"
      ;;
  esac
}

# Reads either a value or a list from plugin config
plugin_read_list_into_result() {
  local key_suffix="${1:-}"
  [[ -z "$key_suffix" ]] && return 0
  prefix_read_list_into_result "BUILDKITE_PLUGIN_${PLUGIN_PREFIX}_${key_suffix}"
}

# Reads a single value (getter)
plugin_read_config() {
  local key_suffix="${1:-}"
  local default="${2:-}"
  [[ -z "$key_suffix" ]] && { echo "$default"; return 0; }
  local var="BUILDKITE_PLUGIN_${PLUGIN_PREFIX}_${key_suffix}"
  echo "${!var:-$default}"
}