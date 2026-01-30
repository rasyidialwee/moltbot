# Moltbot + Ollama (Docker, CPU-only)

Run [Moltbot](https://molt.bot) with [Ollama](https://ollama.com) locally, then migrate the same stack to your home server with [Dockge](https://dockge.kuma.pet/). No GPU.

- **Dashboard**: http://127.0.0.1:18789  
- **Ollama API**: http://127.0.0.1:11434  

## Prerequisites

- Docker and Docker Compose (v2)
- Ports **11434** and **18789** free
- CPU-only (Ollama runs on CPU; same stack runs on a server without GPU)

## Quick start (local)

1. **Copy env and set gateway token**

   ```bash
   cp env.example .env
   # Generate a token:
   openssl rand -hex 32
   # Then paste that value into .env for CLAWDBOT_GATEWAY_TOKEN=
   ```

2. **Create data directories with correct permissions**

   The container runs as the `node` user (UID 1000). Create the data directories with proper ownership **before** starting:

   ```bash
   mkdir -p ./data/moltbot-config ./data/moltbot-workspace
   sudo chown -R 1000:1000 ./data/
   ```

   > **Why?** Docker creates bind-mount directories as root if they don't exist. The `node` user inside the container cannot write to root-owned directories, causing "EACCES: permission denied" errors.

3. **Start the stack**

   ```bash
   docker compose up -d
   ```

   First run builds the Moltbot image from the [official repo](https://github.com/moltbot/moltbot) (may take several minutes).

4. **Pull an Ollama model**

   ```bash
   # Recommended for CPU-only (fast responses)
   docker compose exec ollama ollama pull qwen3:1.8b
   
   # Or a larger model (slower on CPU, better quality)
   # docker compose exec ollama ollama pull qwen3
   ```

   **Check which models are available**

   List models already pulled in the Ollama container:

   ```bash
   docker compose exec ollama ollama list
   ```

   Common models you can pull and use with Moltbot:

   | Model | Size | Description |
   |-------|------|-------------|
   | `qwen3:1.8b` | ~1.5 GB | **Recommended for CPU-only.** Fast responses (~5-10s). |
   | `llama3.2:3b` | ~2 GB | Smaller Llama 3.2 (3B), good for CPU. |
   | `qwen3` | ~5 GB | Qwen 3 8B, general multilingual chat. Slower on CPU (~30s+). |
   | `glm4` | ~5 GB | GLM-4 9B, multilingual general/coding. Slower on CPU. |
   | `llama3.2` | ~4 GB | Llama 3.2 8B, general chat. |
   | `mistral` | ~4 GB | Mistral 7B, general purpose. |
   | `qwen2.5-coder:7b` | ~4.5 GB | Qwen 2.5 Coder, code-focused. |

   > **CPU Performance Tip:** Larger models (7B+) are slow on CPU (30+ seconds per response). For CPU-only setups, use `qwen3:1.8b` or `llama3.2:3b` for faster responses.

   Pull with: `docker compose exec ollama ollama pull <name>` (e.g. `ollama pull qwen3:1.8b`). Then set that model as the default in the config file or Moltbot dashboard.

5. **Open the dashboard (with token)**

   The gateway requires authentication. Open the dashboard with your token in the URL:

   ```
   http://127.0.0.1:18789/?token=YOUR_CLAWDBOT_GATEWAY_TOKEN
   ```

   Replace `YOUR_CLAWDBOT_GATEWAY_TOKEN` with the value you set in `.env`. The token is saved in your browser after first use.

6. **Approve device pairing (first time only)**

   On first connection, you'll see "pairing required" error. The gateway requires you to approve new devices. In another terminal:

   ```bash
   # List pending pairing requests
   docker exec moltbot-gateway node dist/index.js devices list

   # Approve the pending request (use the Request ID from the list)
   docker exec moltbot-gateway node dist/index.js devices approve <REQUEST_ID>
   ```

   After approving, refresh your browser. The device is now paired and won't require approval again.

7. **Configure Ollama in Moltbot**

   - In Settings / Model providers, add **Ollama**
   - Base URL: `http://ollama:11434` (or `http://ollama:11434/v1` if the UI asks for an OpenAI-compatible base URL)
   - Set your chosen model (e.g. `glm4`) as the default

   **If you can't change the model or Ollama URL in the UI**, use a config file so the agent uses Ollama instead of Anthropic:

   ```bash
   # Ensure config dir exists and is writable by the container (UID 1000)
   mkdir -p ./data/moltbot-config
   sudo chown -R 1000:1000 ./data/

   # Copy the example config (uses Ollama as default model; edit the model name if you use something other than qwen3)
   cp config-ollama-default.example.json ./data/moltbot-config/moltbot.json

   # Restart the gateway so it picks up the config
   docker compose restart moltbot-gateway
   ```

   Edit `./data/moltbot-config/moltbot.json` if needed: change `ollama/qwen3` to the model you pulled (e.g. `ollama/llama3.2`, `ollama/qwen2.5-coder:7b`). List models with `docker compose exec ollama ollama list`.

8. **Verify**

   - Ollama: `curl -s http://127.0.0.1:11434/api/tags`
   - Dashboard: start a chat using the Ollama model

## Troubleshooting: Can't access http://127.0.0.1:18789

1. **Check that both containers are running**
   ```bash
   docker compose ps
   ```
   You should see `moltbot-ollama` and `moltbot-gateway` with state "running". If `moltbot-gateway` is exited or restarting, check its logs.

2. **Check gateway logs**
   ```bash
   docker compose logs moltbot-gateway
   ```
   Look for errors (e.g. missing token, bind/port, permission denied, or crash). Fix any reported issue and restart with `docker compose up -d`.

3. **"EACCES: permission denied, mkdir '/home/node/.moltbot/...'"**
   
   The container runs as the `node` user (UID 1000), but Docker creates bind-mount directories as root. Fix by changing ownership:
   ```bash
   sudo chown -R 1000:1000 ./data/
   docker compose restart moltbot-gateway
   ```

4. **Ensure `.env` exists and `CLAWDBOT_GATEWAY_TOKEN` is set**
   The gateway expects a non-empty token. If you didn't set it:
   ```bash
   cp env.example .env
   # Edit .env and set CLAWDBOT_GATEWAY_TOKEN to a random value, e.g.:
   # CLAWDBOT_GATEWAY_TOKEN=$(openssl rand -hex 32)
   docker compose up -d
   ```

5. **"Disconnected from gateway" / "unauthorized: gateway token missing"**
   
   The dashboard page loads but shows a disconnect error. You need to include your token in the URL:
   ```
   http://127.0.0.1:18789/?token=YOUR_CLAWDBOT_GATEWAY_TOKEN
   ```
   Replace `YOUR_CLAWDBOT_GATEWAY_TOKEN` with the value from your `.env` file. The token is saved in your browser's local storage after the first successful connection.

6. **"Disconnected from gateway" / "pairing required"**
   
   The token was accepted but the device (browser) needs to be approved. This is a security feature for new devices:
   ```bash
   # List pending pairing requests
   docker exec moltbot-gateway node dist/index.js devices list

   # Approve the pending request (copy the Request ID from the Pending table)
   docker exec moltbot-gateway node dist/index.js devices approve <REQUEST_ID>
   ```
   After approving, refresh your browser. Each new browser/device will need to be approved once.

7. **Test from the same machine**
   From the host where Docker is running:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789
   ```
   If you get `000` or "connection refused", the gateway isn't listening yet (see logs). If you get `200` or `302`, the dashboard is up; open http://127.0.0.1:18789 in a browser on the **same** machine (127.0.0.1 is localhost only).

8. **If the gateway container keeps restarting**
   Rebuild and restart:
   ```bash
   docker compose build moltbot-gateway --no-cache
   docker compose up -d
   docker compose logs -f moltbot-gateway
   ```

9. **"Invalid --bind (use loopback, lan, ...)"**
   The gateway expects a named bind mode, not an IP address. The `docker-compose.yml` hardcodes `--bind lan` which is required for Docker networking. Do not change this to `loopback` as it will prevent access from outside the container.

10. **"Missing config" or "Failed to move legacy state dir"**
   The stack is set up to use `--allow-unconfigured` so the gateway starts without prior setup. If you still see these errors, ensure you're using the latest `docker-compose.yml`. Then stop, remove the config volume dir so it starts fresh, and bring the stack up again:
   ```bash
   docker compose down
   sudo rm -rf ./data/moltbot-config ./data/moltbot-workspace
   mkdir -p ./data/moltbot-config ./data/moltbot-workspace
   sudo chown -R 1000:1000 ./data/
   docker compose up -d
   ```

11. **"No API key found for provider anthropic" / "Embedded agent failed before reply"**
   The main agent is set to use Anthropic by default but no API key is configured. To use **Ollama only** (no Anthropic):

   - **Option A – Config file (recommended):** Use the Ollama-default config so the agent never asks for Anthropic:
     ```bash
     cp config-ollama-default.example.json ./data/moltbot-config/moltbot.json
     # Edit moltbot.json if your Ollama model is not qwen3 (e.g. change "qwen3" to "llama3.2")
     docker compose restart moltbot-gateway
     ```
   - **Option B – Dashboard:** In Settings → Model providers, add Ollama with Base URL `http://ollama:11434`, then set the default model to an Ollama model (e.g. `ollama/glm4`). If the UI doesn’t show the Ollama base URL or model selector, use Option A.

   Ensure you have pulled at least one Ollama model: `docker compose exec ollama ollama pull qwen3:1.8b` (recommended for CPU) or `qwen3`, `llama3.2`, etc.

## Env vars (see `env.example` or `.env.example`)

| Variable | Purpose |
|----------|--------|
| `CLAWDBOT_GATEWAY_TOKEN` | Required for dashboard auth; generate with `openssl rand -hex 32` |
| `CLAWDBOT_GATEWAY_BIND` | Bind mode (not used in this stack; `docker-compose.yml` hardcodes `--bind lan` for Docker compatibility) |
| `CLAWDBOT_GATEWAY_PORT` | Gateway/dashboard port (default `18789`) |
| `CLAWDBOT_CONFIG_DIR` | Host path for Moltbot config (default `./data/moltbot-config`) |
| `CLAWDBOT_WORKSPACE_DIR` | Host path for workspace (default `./data/moltbot-workspace`) |
| `OLLAMA_API_KEY` | Set to any value (e.g. `ollama-local`) to enable Ollama provider |
| `OLLAMA_BASE_URL` | Gateway → Ollama URL (default `http://ollama:11434` in Docker) |

> **Note on Docker networking**: The gateway must bind to `lan` (0.0.0.0) inside the container for Docker's port mapping to work. Security is enforced by binding to `127.0.0.1` on the host side in `docker-compose.yml`. Do not change `--bind lan` to `loopback` as it will break access.

For production or remote access (e.g. on Dockge), see [Moltbot security guidance](https://docs.molt.bot/gateway/configuration): use `GATEWAY_AUTH_TOKEN` and use Tailscale/Cloudflare Tunnel instead of exposing the port directly.

## Migrate to TrueNAS Server (Dockge)

This section covers deploying Moltbot + Ollama on a TrueNAS SCALE server using Dockge for container management.

### Prerequisites (TrueNAS)

- TrueNAS SCALE with Docker/Apps enabled
- [Dockge](https://dockge.kuma.pet/) installed (via TrueNAS Apps or manual Docker install)
- A ZFS pool for storing data

### Step 1: Create ZFS Datasets

Create dedicated datasets for persistent data. In TrueNAS Web UI:

1. Go to **Datasets** → Select your pool → **Add Dataset**
2. Create the following datasets:

   | Dataset Name | Purpose |
   |--------------|---------|
   | `moltbot` | Parent dataset for all Moltbot data |
   | `moltbot/config` | Moltbot configuration (`moltbot.json`, agent state) |
   | `moltbot/workspace` | Agent workspace files |
   | `moltbot/ollama` | Ollama models (can be large, 5-50+ GB) |
   | `moltbot/stacks` | Dockge stacks (if not already set up) |

   Example paths (assuming pool named `tank`):
   ```
   /mnt/tank/moltbot
   /mnt/tank/moltbot/config
   /mnt/tank/moltbot/workspace
   /mnt/tank/moltbot/ollama
   ```

3. **Set permissions** for the config and workspace datasets (Moltbot runs as UID 1000):
   
   In TrueNAS Shell or SSH:
   ```bash
   # Set ownership to UID 1000 (node user in container)
   chown -R 1000:1000 /mnt/tank/moltbot/config
   chown -R 1000:1000 /mnt/tank/moltbot/workspace
   
   # Ollama runs as root, so leave default permissions
   # chown -R root:root /mnt/tank/moltbot/ollama  # (default)
   ```

### Step 2: Copy Files to TrueNAS

Copy the required files to your Dockge stacks directory:

```bash
# From your local machine (adjust paths as needed)
scp docker-compose.yml Dockerfile env.example config-ollama-default.example.json \
    root@truenas:/mnt/tank/moltbot/stacks/moltbot/
```

Or create a new directory in Dockge's stacks folder and copy the files there.

### Step 3: Create the Stack in Dockge

1. Open Dockge web UI (e.g., `http://truenas:5001`)
2. Click **+ Compose** to create a new stack
3. Name it `moltbot`
4. Paste or edit the `docker-compose.yml` with TrueNAS paths:

```yaml
# Moltbot + Ollama for TrueNAS SCALE
# Adjust /mnt/tank/moltbot to your dataset path

services:
  ollama:
    image: ollama/ollama:latest
    container_name: moltbot-ollama
    ports:
      - "11434:11434"
    volumes:
      - /mnt/tank/moltbot/ollama:/root/.ollama
    restart: unless-stopped

  moltbot-gateway:
    image: moltbot:local
    build:
      context: .
      dockerfile: Dockerfile
    container_name: moltbot-gateway
    environment:
      HOME: /home/node
      TERM: xterm-256color
      CLAWDBOT_GATEWAY_TOKEN: ${CLAWDBOT_GATEWAY_TOKEN}
      CLAWDBOT_GATEWAY_PORT: 18789
      OLLAMA_API_KEY: ollama-local
      OLLAMA_BASE_URL: http://ollama:11434
    volumes:
      - /mnt/tank/moltbot/config:/home/node/.moltbot
      - /mnt/tank/moltbot/workspace:/home/node/clawd
    ports:
      # For LAN access, bind to 0.0.0.0 (or use Tailscale/reverse proxy)
      - "18789:18789"
    depends_on:
      - ollama
    init: true
    restart: unless-stopped
    command:
      [
        "node",
        "dist/index.js",
        "gateway",
        "--bind",
        "lan",
        "--port",
        "18789",
        "--allow-unconfigured"
      ]
```

5. In Dockge, add environment variables or create a `.env` file:
   ```
   CLAWDBOT_GATEWAY_TOKEN=<your-generated-token>
   ```
   
   Generate a token: `openssl rand -hex 32`

### Step 4: Copy the Config File

Before starting, copy the Ollama config so the agent uses Ollama (not Anthropic):

```bash
# SSH into TrueNAS
ssh root@truenas

# Copy and edit the config
cp /mnt/tank/moltbot/stacks/moltbot/config-ollama-default.example.json \
   /mnt/tank/moltbot/config/moltbot.json

# Edit if using a different model (e.g., qwen3:1.8b for faster CPU responses)
nano /mnt/tank/moltbot/config/moltbot.json
```

Ensure permissions:
```bash
chown 1000:1000 /mnt/tank/moltbot/config/moltbot.json
```

### Step 5: Deploy the Stack

1. In Dockge, click **Deploy** (or **Start**)
2. Wait for the images to build/pull (first run takes several minutes)
3. Check logs for errors: click on `moltbot-gateway` → **Logs**

### Step 6: Pull an Ollama Model

```bash
# From TrueNAS shell or Dockge terminal
docker exec moltbot-ollama ollama pull qwen3:1.8b
```

Or use the larger `qwen3` if you have enough RAM and can tolerate slower responses.

### Step 7: Access the Dashboard

1. Open `http://<truenas-ip>:18789/?token=YOUR_TOKEN`
2. Approve device pairing (first time):
   ```bash
   docker exec moltbot-gateway node dist/index.js devices list
   docker exec moltbot-gateway node dist/index.js devices approve <REQUEST_ID>
   ```
3. Refresh the browser and start chatting

### TrueNAS-Specific Tips

- **Backup**: Your datasets (`config`, `workspace`, `ollama`) are on ZFS—set up snapshots/replication for backup.
- **Remote Access**: Use Tailscale or Cloudflare Tunnel instead of exposing port 18789 directly to the internet.
- **Resource Limits**: In Dockge/docker-compose, you can add CPU/memory limits:
  ```yaml
  moltbot-gateway:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
  ollama:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
  ```
- **GPU Passthrough** (if TrueNAS host has NVIDIA GPU): Add to the `ollama` service:
  ```yaml
  ollama:
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
  ```

### Quick Reference: TrueNAS Paths

| Purpose | Dataset Path | Container Mount |
|---------|--------------|-----------------|
| Moltbot config | `/mnt/tank/moltbot/config` | `/home/node/.moltbot` |
| Agent workspace | `/mnt/tank/moltbot/workspace` | `/home/node/clawd` |
| Ollama models | `/mnt/tank/moltbot/ollama` | `/root/.ollama` |

## References

- [Moltbot Docker install](https://docs.molt.bot/install/docker)  
- [Moltbot Ollama provider](https://docs.molt.bot/providers/ollama)  
- [Clawdbot install with Ollama/GLM (Binaryverse)](https://binaryverseai.com/clawdbot-install-ollama-glm-local-model-default/)
