# dockerfiles

Monorepo for my custom Docker images. Each image lives in its own folder and is independently buildable via GitHub Actions. All images are published to DockerHub with `latest` and date-based tags (e.g. `2026.06`).

## Images

| Image | Description | DockerHub |
|-------|-------------|-----------|
| [image-a](./image-a) | ... | `yourusername/image-a` |
| [image-b](./image-b) | ... | `yourusername/image-b` |
| [image-c](./image-c) | ... | `yourusername/image-c` |

## Repository Structure

```
dockerfiles/
├── .github/
│   └── workflows/
│       ├── build-all.yml         # Manually build all images in parallel
│       └── build-single.yml      # Manually build one selected image
├── image-a/
│   ├── Dockerfile
│   └── build.env
├── image-b/
│   ├── Dockerfile
│   └── build.env
└── image-c/
    ├── Dockerfile
    └── build.env
```

## Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `build-single.yml` | Manual | Build and push one selected image |
| `build-all.yml` | Manual | Build and push all images in parallel |

## Tags

Every build pushes two tags:

| Tag | Example | Description |
|-----|---------|-------------|
| `latest` | `yourusername/image-a:latest` | Always points to the most recent build |
| Date | `yourusername/image-a:2026.06` | Year.Month snapshot of the build |

## build.env

Each image folder contains a `build.env` file that defines its metadata:

```bash
IMAGE_NAME=your-image-name         # DockerHub image name (required)
PLATFORMS=linux/amd64,linux/arm64  # Target platforms (optional, defaults to amd64+arm64)
```

## Adding a New Image

1. Create a new folder with your `Dockerfile` and `build.env`
2. Add the folder name to the `options` list in `.github/workflows/build-single.yml`
3. Add a row to the Images table in this README

## GitHub Actions Setup

The following must be configured in your repository settings before workflows can run:

| Type | Key | Description |
|------|-----|-------------|
| Variable (`vars`) | `DOCKERHUB_USERNAME` | Your DockerHub username |
| Secret (`secrets`) | `DOCKERHUB_TOKEN` | Your DockerHub access token |

> Generate a DockerHub token at: Account Settings → Security → New Access Token
