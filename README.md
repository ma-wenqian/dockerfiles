# dockerfiles

Monorepo for my custom Docker images. Each image lives in its own folder and is built by GitHub Actions, then published to both DockerHub and GitHub Container Registry (GHCR).

## Images

| Image                         | Description                                            | DockerHub                       | GHCR                                  |
| ----------------------------- | ------------------------------------------------------ | ------------------------------- | ------------------------------------- |
| [warp](./warp)                | Cloudflare WARP client exposing an HTTP proxy          | `mawenqiandev/warp`             | `ghcr.io/ma-wenqian/warp`             |
| [openconnect](./openconnect)  | OpenConnect built from upstream HEAD with SOCKS5 proxy | `mawenqiandev/openconnect-head` | `ghcr.io/ma-wenqian/openconnect-head` |

The folder name and the published image name can differ: the image name comes from `IMAGE_NAME` in the folder's `build.env` (the `openconnect` folder publishes `openconnect-head`).

## Repository Structure

```
dockerfiles/
├── .github/
│   └── workflows/
│       └── build-Images.yml   # Manually build and push one or more images
├── warp/
│   ├── Dockerfile
│   ├── build.env
│   └── README.md
├── openconnect/
│   ├── Dockerfile
│   ├── build.env
│   └── readme.md
└── README.md
```

## Building

The **Build Images** workflow is triggered manually (Actions → Build Images → Run workflow) and takes two inputs:

| Input    | Example             | Description                                                    |
| -------- | ------------------- | -------------------------------------------------------------- |
| `images` | `warp,openconnect`  | Folder names to build, comma-separated. Each one builds in parallel. |
| `tag`    | `2026.10`           | Extra tag to push. Leave it as `latest` to push `latest` only. |

## Tags

Every build pushes `latest` to both registries. If `tag` is set to anything other than `latest`, that tag is pushed as well:

| Tag      | Example                              | Description                            |
| -------- | ------------------------------------ | -------------------------------------- |
| `latest` | `mawenqiandev/warp:latest`           | Always points to the most recent build |
| Custom   | `mawenqiandev/warp:2026.10`          | Whatever you entered as `tag`          |

## build.env

Each image folder contains a `build.env` file that defines its metadata:

```bash
IMAGE_NAME=your-image-name         # Published image name (required)
PLATFORMS=linux/amd64,linux/arm64  # Target platforms (optional, defaults to amd64+arm64)
```

## Adding a New Image

1. Create a new folder with your `Dockerfile` and `build.env`
2. Run the **Build Images** workflow with the folder name in `images`
3. Add a row to the Images table in this README

## GitHub Actions Setup

The following must be configured in your repository settings before the workflow can run:

| Type               | Key                  | Description                 |
| ------------------ | -------------------- | --------------------------- |
| Variable (`vars`)  | `DOCKERHUB_USERNAME` | Your DockerHub username     |
| Secret (`secrets`) | `DOCKERHUB_TOKEN`    | Your DockerHub access token |

> Generate a DockerHub token at: Account Settings → Security → New Access Token

Pushing to GHCR uses the built-in `GITHUB_TOKEN`; the workflow already requests `packages: write`, so nothing else needs to be set up.
