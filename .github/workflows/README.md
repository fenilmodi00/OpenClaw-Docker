# 📘 Docker Build & Push Workflow Documentation 

## Overview

This GitHub Actions workflow automatically builds a Docker image and pushes it to **Docker Hub** and **GitHub Container Registry (GHCR)** whenever the `version.txt` file is updated.

---

## Triggers

The workflow runs under the following conditions:

1. **Automatic trigger**

   * When `version.txt` is modified and pushed to the `main` or `master` branch
2. **Manual trigger**

   * When manually started from the GitHub Actions UI

---

## Setup Instructions

### 1. Configure GitHub Secrets

In your GitHub repository, go to:

**Settings → Secrets and variables → Actions → New repository secret**

Add the following secrets:

| Secret Name          | Description                | Example                 |
| -------------------- | -------------------------- | ----------------------- |
| `DOCKERHUB_USERNAME` | Docker Hub username        | `myusername`            |
| `DOCKERHUB_TOKEN`    | Docker Hub access token    | Generated on Docker Hub |
| `DOCKERHUB_REPO`     | Docker Hub repository name | `openclaw-gateway`      |

> `GITHUB_TOKEN` is provided automatically by GitHub.

---

### 2. Generate a Docker Hub Access Token

1. Log in to [Docker Hub](https://hub.docker.com/)
2. Click your avatar → **Account Settings**
3. Go to **Security** → **New Access Token**
4. Give it a name (e.g. `GitHub Actions`)
5. Copy the token and save it as `DOCKERHUB_TOKEN`

---

### 3. Create a Docker Hub Repository

1. Log in to Docker Hub
2. Click **Create Repository**
3. Enter a repository name (e.g. `openclaw-gateway`)
4. Choose **Public** or **Private**
5. Create the repository

---

## Usage

### Method 1: Update the Version File (Recommended)

1. Update `version.txt`:

   ```bash
   echo "1.0.1" > version.txt
   ```

2. Commit and push:

   ```bash
   git add version.txt
   git commit -m "chore: bump version to 1.0.1"
   git push origin main
   ```

3. The workflow will start automatically.

---

### Method 2: Manual Trigger

1. Go to your GitHub repository
2. Open the **Actions** tab
3. Select **Build and Push Docker Image**
4. Click **Run workflow**
5. Choose a branch and start the workflow

---

## Docker Image Tags

### Docker Hub

* `<username>/<repo>:<version>` (e.g. `1.0.0`)
* `<username>/<repo>:latest`
* `<username>/<repo>:<branch>-<sha>`

### GitHub Container Registry (GHCR)

* `ghcr.io/<owner>/<repo>:<version>`
* `ghcr.io/<owner>/<repo>:latest`
* `ghcr.io/<owner>/<repo>:<branch>-<sha>`

---

## Pulling the Image

### From Docker Hub

```bash
docker pull <username>/<repo>:1.0.0
docker pull <username>/<repo>:latest
```

### From GHCR

```bash
docker pull ghcr.io/<owner>/<repo>:1.0.0
docker pull ghcr.io/<owner>/<repo>:latest
```

---

## Multi-Architecture Support

This workflow builds images for:

* `linux/amd64` (x86_64)
* `linux/arm64` (Apple Silicon, ARM servers, Raspberry Pi)

Docker automatically pulls the correct image for your platform.

---

## Versioning Guidelines

Use **Semantic Versioning**:

* **MAJOR** – Breaking changes (`2.0.0`)
* **MINOR** – Backward-compatible features (`1.1.0`)
* **PATCH** – Bug fixes (`1.0.1`)

Example:

```
1.0.0  # Initial release
1.0.1  # Bug fix
1.1.0  # New feature
2.0.0  # Breaking change
```

---

## Workflow Features

* ✅ Automatically reads version from `version.txt`
* ✅ Pushes to Docker Hub and GHCR
* ✅ Multi-architecture builds (amd64 & arm64)
* ✅ GitHub Actions cache for faster builds
* ✅ Automatic tag generation (version, latest, SHA)
* ✅ Clear build logs and output

---

## Troubleshooting

### Docker Hub Login Failure

* Verify `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`
* Ensure the token is valid and not expired
* Confirm push permissions

### GHCR Push Failure

* Ensure repository permissions allow `packages: write`
* Check `GITHUB_TOKEN` permissions

### Build Timeout

* Optimize Dockerfile layers
* Reduce image size
* Ensure cache is enabled

---

## Related Files

* `version.txt` – Version source
* `Dockerfile` – Image build definition
* `.github/workflows/docker-build-push.yml` – CI workflow

