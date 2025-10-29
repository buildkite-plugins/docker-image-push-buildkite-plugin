# Docker Image Push Buildkite Plugin

A Buildkite plugin to build and push Docker images to a variety of container registries.

Supported providers:
- Amazon Elastic Container Registry (ECR)
- Google Artifact Registry (GAR)
- Buildkite Package Registries
- Artifactory Docker Registry
- Namespace Container Registry (requires Namespace CLI)

## Options

These are all the options available to configure this plugin's behaviour.

### Required

#### `provider` (string)

The registry provider to use. Supported values: `ecr`, `gar`, `buildkite`, `artifactory`, `namespace`.

#### `image` (string)

The name of the Docker image to push (e.g., `my-org/my-app`).

### Optional

#### `tag` (string, default: `latest`)

The tag for the Docker image.

#### `verbose` (boolean, default: `false`)

Enable debug mode, which runs the plugin scripts with `set -x` to provide detailed command tracing. Set to `true`, `on`, or `1` to enable.

### ECR Provider Options

#### `region` (string)

The AWS region for the ECR registry.

#### `registry-url` (string)

The full URL of the ECR registry (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com`).

### GAR Provider Options

**Note:** Authentication is handled by the `gcloud` CLI. Ensure your Buildkite agent has authenticated with Google Cloud before running this plugin (e.g., using a service account key or Workload Identity Federation).

#### `gar-project` (string)

The Google Cloud project ID.

#### `region` (string, default: `us`)

The GAR region (e.g., `us-east1`) or a full GAR hostname (e.g., `europe-west10-docker.pkg.dev`).

#### `repository` (string)

The name of the Artifact Registry repository. If omitted, it defaults to the image name.

### Buildkite Packages Provider Options

**Note:** Authentication requires either a Buildkite API token with Read Packages and Write Packages scopes, or OIDC authentication using `buildkite-agent` (available in Buildkite pipeline jobs).

#### `org-slug` (string)

The Buildkite organization slug. If omitted, it will use the `BUILDKITE_ORGANIZATION_SLUG` environment variable.

#### `registry-slug` (string)

The container registry slug. If omitted, it defaults to the image name.

#### `auth-method` (string, default: `api-token`)

Authentication method to use. Supported values: `api-token`, `oidc`.

- `api-token`: Uses the `api-token` parameter or falls back to `BUILDKITE_API_TOKEN` environment variable
- `oidc`: Uses `buildkite-agent oidc request-token` command (available in pipeline jobs)

#### `api-token` (string)

The Buildkite API token with Read Packages and Write Packages scopes. Required when `auth-method` is `api-token`. Can also be provided via the `BUILDKITE_API_TOKEN` environment variable for backward compatibility.

### Artifactory Provider Options

**Note:** Authentication requires a username (typically email) and identity token from your Artifactory instance.

#### `registry-url` (string)

The Artifactory registry URL (e.g., `myjfroginstance.jfrog.io`). Do not include the protocol (`https://`).

#### `username` (string)

The username for Artifactory authentication, typically your email address.

#### `identity-token` (string)

The Artifactory identity token for authentication. Can reference an environment variable using `$VARIABLE_NAME` syntax.

### Namespace Provider Options

**Important:** This plugin authenticates to Namespace and pushes an image that already exists in the local Docker daemon. It does **not** trigger Namespace remote builds. If you want to build remotely, run `nsc docker buildx build --push` yourself and let the remote builder push directly to `nscr.io`.

#### `tenant-id` (string)

The Namespace tenant/workspace ID (for example `tenant_abcd1234`). The plugin automatically derives the registry slug (`abcd1234`) from this value when tagging images.

#### `registry` (string, default: `nscr.io`)

Namespace registry host. Override only if you use a custom registry domain.

#### `nsc-binary` (string, default: `/root/.ns/bin/nsc`)

Path to the Namespace CLI (`nsc`). Leave unset if the CLI is available on `PATH`, or override if it is installed in a non-standard location.

#### `auth-method` (string, default: `buildkite-oidc`)

Authentication method to use. Supported values: `buildkite-oidc`, `aws-cognito`.

- `buildkite-oidc`: Uses `buildkite-agent oidc request-token`. Available only in Buildkite pipelines with OIDC enabled.
- `aws-cognito`: Exchanges AWS credentials for a Namespace token via Cognito. Requires the additional fields below. See the [Namespace AWS Cognito federation guide](https://docs.namespace.so/docs/solutions/docker-builders#authenticate-with-aws-cognito) for cluster setup requirements.

#### `buildkite-oidc.audience` (string, default: `federation.namespaceapis.com`)

Custom OIDC audience when using `auth-method: buildkite-oidc`.

#### `aws-cognito.region` (string)

AWS region that hosts the Cognito identity pool (for example `us-east-1`).

#### `aws-cognito.identity-pool` (string)

Full Cognito identity pool identifier (GUID such as `217947c4-e20e-4315-97f8-08e9a14c8dfb`).

## Examples

### Push to Amazon ECR

This example pushes an image to an ECR repository.

```yaml
steps:
  - label: ":docker: Build and Push"
    plugins:
      - docker-image-push#v1.1.0:
          provider: ecr
          image: my-app
          ecr:
            region: us-east-1
            registry-url: 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### Push to Google Artifact Registry

This example pushes an image to a GAR repository with a specific tag.

```yaml
steps:
  - label: ":docker: Build and Push"
    plugins:
      - docker-image-push#v1.1.0:
          provider: gar
          image: my-app
          tag: "v1.2.3"
          gar:
            project: my-gcp-project
            region: australia-southeast1
            repository: my-docker-repo
```

### Push to Buildkite Packages Container Registry

This example pushes an image to Buildkite Packages using API token authentication.

```yaml
steps:
  - label: ":docker: Build and Push"
    plugins:
      - docker-image-push#v1.1.0:
          provider: buildkite
          image: my-app
          tag: "v1.2.3"
          buildkite:
            org-slug: my-org
            registry-slug: my-container-registry
            api-token: your-api-token-here
```

### Push to Buildkite Packages with OIDC

This example uses OIDC authentication (recommended for Buildkite pipelines).

```yaml
steps:
  - label: ":docker: Build and Push"
    plugins:
      - docker-image-push#v1.1.0:
          provider: buildkite
          image: my-app
          buildkite:
            org-slug: my-org
            auth-method: oidc
```

### Push to Artifactory Docker Registry

This example pushes an image to an Artifactory Docker registry.

```yaml
steps:
  - label: ":docker: Build and Push"
    plugins:
      - docker-image-push#v1.1.0:
          provider: artifactory
          image: my-app
          tag: "v1.2.3"
          artifactory:
            registry-url: myjfroginstance.jfrog.io
            username: me@example.com
            identity-token: $ARTIFACTORY_IDENTITY_TOKEN
```

### Push to Namespace Container Registry (local build + push)

This example builds an image locally on a Docker-capable agent (or DinD pod) and lets the plugin authenticate and push to Namespace using Buildkite OIDC. The Namespace CLI must be installed and accessible, along with `docker-credential-nsc` on the agent `PATH`.

```yaml
steps:
  - label: ":namespace: Build & Push"
    command: |
      set -euo pipefail
      docker build -t "namespace-app:latest" .
    plugins:
      - docker-image-push#v1.1.0:
          provider: namespace
          image: "namespace-app"
          tag: "latest"
          namespace:
            tenant-id: "tenant_abcd1234"
            auth-method: buildkite-oidc
            buildkite-oidc:
              audience: "federation.namespaceapis.com"
```

### Verbose Mode

Enable verbose mode for detailed debug output.

```yaml
steps:
  - label: ":docker: Build and Push (Debug)"
    plugins:
      - docker-image-push#v1.1.0:
          provider: ecr
          image: my-app
          verbose: true
```

## Compatibility

| Elastic Stack | Agent Stack K8s | Hosted (Mac) | Hosted (Linux) | Notes |
| :-----------: | :-------------: | :----: | :----: |:---- |
| ✅ |  ⚠️ | ❌ | ⚠️ | **All** – Requires `awscli`, `gcloud`, `docker`, `nsc` for ECR, GAR and Namespace respectively. Buildkite Packages only requires `docker`<br/>**Hosted (Mac)** - Docker engine not available |

- ✅ Fully supported (all combinations of attributes have been tested to pass)
- ⚠️ Partially supported (some combinations cause errors/issues)
- ❌ Not supported

## 👩‍💻 Contributing

Contributions are welcome! Please open a pull request with your changes.

## 📜 License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
