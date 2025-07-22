#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_IMAGE='test-image'
  export BUILDKITE_PLUGIN_DOCKER_IMAGE_PUSH_TAG='test-tag'
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
  assert_failure  # Expected to fail due to missing AWS CLI
  assert_output --partial 'Enabling debug mode'
  assert_output --partial '+ echo'
}