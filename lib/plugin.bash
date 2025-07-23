#!/bin/bash

# Load shared utilities
# shellcheck source=lib/shared.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shared.bash"

# Load provider implementations
# shellcheck source=lib/providers/ecr.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/providers/ecr.bash"
# shellcheck source=lib/providers/gar.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/providers/gar.bash"

setup_provider_environment() {
  local provider="$1"

  case "$provider" in
    ecr)
      setup_ecr_environment
      ;;
    gar)
      setup_gar_environment
      ;;

    *)
      unknown_provider "$provider"
      ;;
  esac
}
