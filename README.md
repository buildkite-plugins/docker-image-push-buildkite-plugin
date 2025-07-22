# Docker Push Buildkite Plugin

A Buildkite plugin to build and push Docker images to a variety of container registries.

Supported providers:
- Amazon Elastic Container Registry (ECR)
- Google Artifact Registry (GAR)

## Options

These are all the options available to configure this plugin's behaviour.

### Required

#### `provider` (string)

The registry provider to use. Supported values: `ecr`, `gar`.

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

## Examples

### Push to Amazon ECR

This example pushes an image to an ECR repository.

```yaml
steps:
  - label: ":docker: Build and Push"
    plugins:
      - docker-push#v1.0.0:
          provider: ecr
          image: my-app
          region: us-east-1
          registry-url: 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### Push to Google Artifact Registry

This example pushes an image to a GAR repository with a specific tag.

```yaml
steps:
  - label: ":docker: Build and Push"
    plugins:
      - docker-push#v1.0.0:
          provider: gar
          image: my-app
          tag: "v1.2.3"
          project: my-gcp-project
          region: australia-southeast1
          repository: my-docker-repo
```

### Verbose Mode

Enable verbose mode for detailed debug output.

```yaml
steps:
  - label: ":docker: Build and Push (Debug)"
    plugins:
      - docker-push#v1.0.0:
          provider: ecr
          image: my-app
          verbose: true
```
## Compatibility

| Elastic Stack | Agent Stack K8s | Hosted (Mac) | Hosted (Linux) | Notes |
| :-----------: | :-------------: | :----: | :----: |:---- |
| ? | ? | ? | ? | n/a |

- ✅ Fully supported (all combinations of attributes have been tested to pass)
- ⚠️ Partially supported (some combinations cause errors/issues)
- ❌ Not supported

## 👩‍💻 Contributing

Contributions are welcome! Please open a pull request with your changes.

## 📜 License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
