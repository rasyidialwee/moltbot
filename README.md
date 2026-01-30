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
   docker compose exec ollama ollama pull glm4
   ```

   Or: `ollama pull llama3.2`, `ollama pull mistral`, etc.

   **Check which models are available**

   List models already pulled in the Ollama container:

   ```bash
   docker compose exec ollama ollama list
   ```

   Common models you can pull and use with Moltbot:

   | Model | Description |
   |-------|-------------|
   | `glm4` | GLM-4, multilingual general/coding (e.g. ~9B params). |
   | `llama3.2` | Llama 3.2, general chat. |
   | `llama3.2:3b` | Smaller Llama 3.2 (3B), lighter on CPU. |
   | `mistral` | Mistral 7B, general purpose. |
   | `qwen2.5-coder:7b` | Qwen 2.5 Coder, code-focused. |
   | `qwen3` | Qwen 3, general multilingual chat. |
   | `qwen3-coder` / `qwen3-coder:30b` | [Qwen3-Coder](https://github.com/QwenLM/Qwen3-Coder): code version of Qwen3 (30B, 256K context). |

   Pull with: `docker compose exec ollama ollama pull <name>` (e.g. `ollama pull glm4`). Then set that model as the default in the Moltbot dashboard (Settings → Model providers → Ollama).

5. **Configure Ollama in Moltbot**

   - Open http://127.0.0.1:18789
   - In Settings / Model providers, add **Ollama**
   - Base URL: `http://ollama:11434` (or `http://ollama:11434/v1` if the UI asks for an OpenAI-compatible base URL)
   - Set your chosen model (e.g. `glm4`) as the default

6. **Verify**

   - Ollama: `curl -s http://127.0.0.1:11434/api/tags`
   - Dashboard: open http://127.0.0.1:18789 and start a chat using the Ollama model

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

3. **"EACCES: permission denied, mkdir '/home/node/.openclaw/...'"**
   
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

5. **Test from the same machine**
   From the host where Docker is running:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789
   ```
   If you get `000` or "connection refused", the gateway isn't listening yet (see logs). If you get `200` or `302`, the dashboard is up; open http://127.0.0.1:18789 in a browser on the **same** machine (127.0.0.1 is localhost only).

6. **If the gateway container keeps restarting**
   Rebuild and restart:
   ```bash
   docker compose build moltbot-gateway --no-cache
   docker compose up -d
   docker compose logs -f moltbot-gateway
   ```

7. **"Invalid --bind (use loopback, lan, ...)"**
   The gateway expects a named bind mode, not an IP address. The `docker-compose.yml` hardcodes `--bind lan` which is required for Docker networking. Do not change this to `loopback` as it will prevent access from outside the container.

8. **"Missing config" or "Failed to move legacy state dir (.clawdbot → .openclaw)"**
   The stack is set up to use the new config path (`.openclaw`) and `--allow-unconfigured` so the gateway starts without prior setup. If you still see these errors, ensure you're using the latest `docker-compose.yml`. Then stop, remove the config volume dir so it starts fresh, and bring the stack up again:
   ```bash
   docker compose down
   sudo rm -rf ./data/moltbot-config ./data/moltbot-workspace
   mkdir -p ./data/moltbot-config ./data/moltbot-workspace
   sudo chown -R 1000:1000 ./data/
   docker compose up -d
   ```

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

## Migrate to home server (Dockge)

1. Copy this project (or at least `docker-compose.yml`, `Dockerfile`, and `env.example`) to the server.
2. Create a new stack in Dockge and point it at your `docker-compose.yml` (and `.env` if you use one).
3. Ensure `.env` on the server has `CLAWDBOT_GATEWAY_TOKEN` set. For remote access, set `GATEWAY_AUTH_TOKEN` and adjust `CLAWDBOT_GATEWAY_BIND` only if you are behind a secure tunnel.
4. Deploy; no GPU config needed (stack is CPU-only).

## References

- [Moltbot Docker install](https://docs.molt.bot/install/docker)  
- [Moltbot Ollama provider](https://docs.molt.bot/providers/ollama)  
- [Clawdbot install with Ollama/GLM (Binaryverse)](https://binaryverseai.com/clawdbot-install-ollama-glm-local-model-default/)
