# Dev Container — Asset Manager Workshop

This devcontainer provides a complete, pre-configured environment for the **GitHub Copilot app modernization** workshop ([README.md](../README.md)). It installs both **JDK 8** (for the starting state of the app) and **JDK 21** (for the post-upgrade state), Docker, Azure CLI + extensions, `azd`, `kubectl`/`helm`, the GitHub CLI, and the [`vscjava.migrate-java-to-azure`](https://marketplace.visualstudio.com/items?itemName=vscjava.migrate-java-to-azure) extension that drives the workshop.

It is **multi-architecture** (linux/amd64 + linux/arm64) and runs identically on:
- Windows + Docker Desktop / WSL2
- macOS Intel and Apple Silicon
- Linux amd64 and arm64

> **Architecture constraint.** The `docker-outside-of-docker` feature requires the container and host to share the same chip architecture (no x86-on-arm emulation). The multi-arch base image satisfies this automatically — do not force `--platform=linux/amd64` on Apple Silicon.

## Quick start

### Prerequisites

- Docker Desktop installed and running (or another OCI runtime with a Linux socket)
- VS Code with the **Dev Containers** extension (`ms-vscode-remote.remote-containers`)
- 4 GB RAM minimum allocated to Docker
- ~6 GB disk space

### Opening the devcontainer

1. Open VS Code in this repository folder.
2. `F1` → **Dev Containers: Reopen in Container**.
3. Wait 3–5 minutes for the first build. Subsequent opens are seconds.

### First-time setup (inside container)

```bash
# Authenticate with Azure (interactive)
az login

# Build the asset-manager
./mvnw -pl web,worker -am clean package

# Run the full stack locally (Postgres + RabbitMQ + web + worker)
scripts/startapp.sh
```

The web app is at <http://localhost:8080>, RabbitMQ management at <http://localhost:15672> (`guest`/`guest`).

## GitHub CLI authentication (`GH_TOKEN`)

HTTPS-based `gh auth login` can fail inside devcontainers on some platforms (Windows, ARM, WSL 2). The supported approach is a Personal Access Token (PAT) set in **VS Code User Settings**. The container reads it automatically — **no `gh auth login` required inside the container**.

> **Why not shell exports?** Setting `GH_TOKEN` in `~/.bashrc`, `~/.profile`, or PowerShell environment variables does not propagate reliably into devcontainers. VS Code reads `${localEnv:GH_TOKEN}` from its own process environment, which only inherits from the specific shell session that launched it. The VS Code User Settings method is deterministic and survives rebuilds, reboots, and IDE restarts.

### Step 1 — Create a fine-grained PAT

Fine-grained PATs work here. The `gh` CLI fully supports fine-grained tokens (`github_pat_...`) via the `GH_TOKEN` environment variable for repository-scoped operations.

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**.
2. Click **Generate new token**.
3. Set expiry (90 days recommended — rotate via a calendar reminder).
4. **Repository access**: *All repositories*, or select specific ones (the asset-manager repo is enough).
5. **Permissions** — minimum required:

   | Permission     | Access      |
   |----------------|-------------|
   | Contents       | Read/Write  |
   | Metadata       | Read        |
   | Pull requests  | Read/Write  |
   | Issues         | Read/Write  |
   | Workflows      | Read/Write  |

6. Copy the token (`github_pat_...`).

### Step 2 — Add to VS Code User Settings (once per machine)

1. Open VS Code Settings: `Ctrl+,` (or `Cmd+,` on macOS).
2. Click the **Open Settings (JSON)** icon (top-right of the Settings tab).
3. Add the entry for your host OS (replace the placeholder with your real token):

   ```jsonc
   // Linux / WSL host:
   "terminal.integrated.env.linux":   { "GH_TOKEN": "github_pat_your_token_here" },
   // macOS host:
   "terminal.integrated.env.osx":     { "GH_TOKEN": "github_pat_your_token_here" },
   // Windows host:
   "terminal.integrated.env.windows": { "GH_TOKEN": "github_pat_your_token_here" }
   ```

4. Save the file.
5. Rebuild the devcontainer: `F1` → **Dev Containers: Rebuild Container**.

The devcontainer forwards `GH_TOKEN` from VS Code's environment automatically (`"GH_TOKEN": "${localEnv:GH_TOKEN}"` in [`devcontainer.json`](./devcontainer.json) under `remoteEnv`).

### Step 3 — Verify inside the container

```bash
gh auth status
# Expected: ✓ Logged in to github.com as <your-username> (token)
```

If you see `You are not logged into any GitHub hosts`, the token is missing or empty — confirm Step 2 and rebuild the container (a full restart isn't enough; the env var is captured at the time VS Code attaches).

**Token rotation.** When your PAT expires, update the value in VS Code User Settings and rebuild the container.

## Environment variables

| Variable    | Default                  | Purpose |
|-------------|--------------------------|---------|
| `GH_TOKEN`  | `${localEnv:GH_TOKEN}`   | GitHub PAT forwarded from host via VS Code User Settings |
| `JAVA_HOME` | JDK 8 (SDKMAN current)   | Default JDK to match the starting state's `<java.version>8</java.version>`. Switch to JDK 21 with `sdk use java <id>`. |

The Java extension is also configured (see `java.configuration.runtimes` in [`devcontainer.json`](./devcontainer.json)) so it picks the right JDK per project automatically — JDK 8 for the starting state, JDK 21 after the workshop's Java upgrade step.

## Forwarded ports

| Port  | Service               | Auto-open |
|-------|-----------------------|-----------|
| 8080  | Asset Manager web UI  | Yes (preview) |
| 15672 | RabbitMQ management   | No        |
| 5432  | PostgreSQL            | Silent    |
| 5672  | RabbitMQ AMQP         | Silent    |

## Mounts

| Mount target            | Source                                 | Purpose |
|-------------------------|----------------------------------------|---------|
| `/home/vscode/.config/gh` | `devcontainer-gh-config-${devcontainerId}` (Docker volume) | Persist `gh` CLI config across rebuilds. |

Host Docker socket is exposed via the `docker-outside-of-docker` feature (not a manual mount).

## When to rebuild vs restart

| Situation                                  | Action |
|--------------------------------------------|--------|
| Updated `GH_TOKEN` in VS Code settings     | `F1` → **Dev Containers: Rebuild Container** |
| Devcontainer feature added or version bumped | `F1` → **Dev Containers: Rebuild Container** |
| Tool not found after restart               | Rerun `./mvnw -v` and check `JAVA_HOME` |
| Base image changed                         | `F1` → **Dev Containers: Rebuild Container Without Cache** |

## Troubleshooting

| Issue                                | Resolution |
|--------------------------------------|------------|
| Container won't start                | Confirm Docker Desktop is running; allocate ≥ 4 GB RAM |
| `docker: command not found` inside   | The `docker-outside-of-docker` feature needs the host socket — restart Docker Desktop and rebuild |
| `gh: not authenticated`              | Set `GH_TOKEN` in VS Code User Settings (above) and rebuild |
| `mvnw` reports JDK 21 but you wanted JDK 8 | `sdk use java $(sdk list java \| grep -E ' 8\..*tem' \| awk '{print $NF}' \| head -1)` |
| Port 8080 already in use             | Stop conflicting processes or change `forwardPorts` in `devcontainer.json` |

## Security notes

- `GH_TOKEN` is injected via VS Code User Settings on the host — **never** commit it to the repo or to `devcontainer.json`.
- Azure credentials persist in `~/.azure/` on the host; the workshop's deployment scripts use `az login` device-code flow.
- The starting-state [`application.properties`](../web/src/main/resources/application.properties) intentionally contains placeholder plaintext credentials — those are the "before" state students migrate away from. Do not commit real secrets to that file.
