#!/bin/bash

# Load shared utilities
# shellcheck source=lib/shared.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shared.bash"

# Load provider implementations
# shellcheck source=lib/providers/ecr.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/providers/ecr.bash"
# shellcheck source=lib/providers/gar.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/providers/gar.bash"
# shellcheck source=lib/providers/buildkite.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/providers/buildkite.bash"

setup_provider_environment() {
  local provider="$1"

  case "$provider" in
    ecr)
      setup_ecr_environment
      ;;
    gar)
      setup_gar_environment
      ;;
    buildkite)
      setup_buildkite_environment
      ;;
    *)
      unknown_provider "$provider"
      ;;
  esac
}
