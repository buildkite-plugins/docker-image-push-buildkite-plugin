#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG='test-tag'

  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat <<'EOF' >"$BATS_TEST_TMPDIR/bin/docker"
#!/bin/bash
if [[ "$1" == "login" || "$1" == "tag" || "$1" == "push" ]]; then
  exit 0
fi
echo "unexpected docker call: $*" >&2
exit 1
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/docker"

  cat <<'EOF' >"$BATS_TEST_TMPDIR/bin/nsc"
#!/bin/bash
if [[ "$1" == "auth" ]]; then
  shift
  case "$1" in
    exchange-oidc-token|exchange-aws-cognito-token)
      exit 0
      ;;
  esac
elif [[ "$1" == "docker" && "$2" == "login" ]]; then
  exit 0
fi
echo "unexpected nsc call: $*" >&2
exit 1
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/nsc"
}

@test "Fails if provider is missing" {
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'provider is required'
}

@test "Fails if image is missing" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='ecr'
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'image is required'
}

@test "ECR provider requires AWS CLI" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='ecr'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ECR_REGION='us-west-2'
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'AWS CLI is required'
}

@test "GAR provider requires gcloud" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='gar'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_GAR_PROJECT='test-project'
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'Google Cloud SDK is required'
}

@test "Buildkite provider requires organization slug" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='buildkite'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  unset BUILDKITE_ORGANIZATION_SLUG
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'organization slug is required'
}

@test "Buildkite provider with API token auth requires token" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='buildkite'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_BUILDKITE_ORG_SLUG='test-org'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_BUILDKITE_AUTH_METHOD='api-token'
  unset BUILDKITE_API_TOKEN
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'API token is required for api-token authentication'
}

@test "Buildkite provider with OIDC auth uses buildkite-agent" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='buildkite'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_BUILDKITE_ORG_SLUG='test-org'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_BUILDKITE_AUTH_METHOD='oidc'
  run "$PWD"/hooks/environment
  assert_failure # Expected to fail at buildkite-agent command (not available in test env)
  assert_output --partial 'Requesting OIDC token for audience'
}

@test "Buildkite provider uses organization slug from environment" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='buildkite'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_ORGANIZATION_SLUG='env-org'
  export BUILDKITE_API_TOKEN='test-token'
  run "$PWD"/hooks/environment
  assert_failure # Expected to fail at docker login (no real docker in test)
  assert_output --partial 'Using organization slug from environment: env-org'
}

@test "Fails on unsupported provider" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='unknown'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'unsupported provider'
}

@test "Verbose mode enables debug output" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='ecr'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_VERBOSE='true'
  run "$PWD"/hooks/environment
  assert_failure # Expected to fail due to missing AWS CLI
  assert_output --partial 'Enabling debug mode'
  assert_output --partial '+ echo'
}

@test "Artifactory provider requires registry URL" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='artifactory'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_USERNAME='test@example.com'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_IDENTITY_TOKEN='test-token'
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_REGISTRY_URL
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'Artifactory registry URL is required'
}

@test "Artifactory provider requires username" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='artifactory'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_REGISTRY_URL='test.jfrog.io'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_IDENTITY_TOKEN='test-token'
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_USERNAME
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'Artifactory username is required'
}

@test "Artifactory provider requires identity token" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='artifactory'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_REGISTRY_URL='test.jfrog.io'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_USERNAME='test@example.com'
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_IDENTITY_TOKEN
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'Artifactory identity token is required'
}

@test "Artifactory provider processes environment variable token" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='artifactory'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_REGISTRY_URL='test.jfrog.io'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_USERNAME='test@example.com'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_IDENTITY_TOKEN='$TEST_TOKEN'
  export TEST_TOKEN='actual-token-value'
  run "$PWD"/hooks/environment
  assert_failure # Expected to fail at docker login (no real docker in test)
  assert_output --partial 'Authenticating with Artifactory Docker registry'
}

@test "Artifactory provider fails when environment variable is empty" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='artifactory'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_REGISTRY_URL='test.jfrog.io'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_USERNAME='test@example.com'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_ARTIFACTORY_IDENTITY_TOKEN='$EMPTY_TOKEN'
  unset EMPTY_TOKEN
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial "Environment variable 'EMPTY_TOKEN' referenced by identity-token parameter is empty or not set"
}

@test "Namespace provider requires tenant id" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='namespace'
  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'Namespace tenant-id is required'
}

@test "Namespace provider with OIDC authenticates via buildkite-agent" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='namespace'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_TENANT_ID='tenant123'

  cat <<'EOF' >"$BATS_TEST_TMPDIR/bin/buildkite-agent"
#!/bin/bash
if [[ "$1" == "oidc" && "$2" == "request-token" ]]; then
  echo "mock-token"
  exit 0
fi
echo "unexpected buildkite-agent call: $*" >&2
exit 1
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/buildkite-agent"

  run "$PWD"/hooks/environment
  assert_success
  assert_output --partial 'Authenticated with Namespace using Buildkite OIDC'
  assert_output --partial 'Namespace remote image: nscr.io/tenant123/test-image:test-tag'
}

@test "Namespace provider with aws-cognito requires region" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='namespace'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_TENANT_ID='tenant123'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_AUTH_METHOD='aws-cognito'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_AWS_COGNITO_IDENTITY_POOL='pool-123'

  run "$PWD"/hooks/environment
  assert_failure
  assert_output --partial 'Namespace aws-cognito.region is required when auth-method is aws-cognito'
}

@test "Namespace provider with aws-cognito authenticates" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_PROVIDER='namespace'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_TENANT_ID='tenant123'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_AUTH_METHOD='aws-cognito'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_AWS_COGNITO_REGION='us-east-1'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_NAMESPACE_AWS_COGNITO_IDENTITY_POOL='pool-123'

  run "$PWD"/hooks/environment
  assert_success
  assert_output --partial 'Authenticated with Namespace using AWS Cognito'
  assert_output --partial 'Namespace remote image: nscr.io/tenant123/test-image:test-tag'
}
