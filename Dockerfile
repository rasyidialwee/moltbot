# Build Moltbot gateway image from official repo (same logic as github.com/moltbot/moltbot Dockerfile).
# CPU-only; no GPU. Used by docker-compose for local run and Dockge migration.
FROM node:22-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable
WORKDIR /app

ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $CLAWDBOT_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

RUN git clone --depth 1 https://github.com/moltbot/moltbot.git .

RUN corepack prepare pnpm@10.23.0 --activate
RUN pnpm install --frozen-lockfile
RUN CLAWDBOT_A2UI_SKIP_MISSING=1 pnpm build
ENV CLAWDBOT_PREFER_PNPM=1
RUN pnpm ui:install && pnpm ui:build

ENV NODE_ENV=production
USER node

CMD ["node", "dist/index.js"]
