# minimal-runner — 轻量级 GitHub Actions 自建 Runner
#
# 设计原则:
# - 最小化：只装 runner 必需的工具，没有 Docker-in-Docker
# - 安全：不挂载 /var/run/docker.sock，不以 root 运行
# - 轻量：基于 debian:bookworm-slim，镜像约 500MB

FROM debian:bookworm-slim

LABEL maintainer="Hawaiine" \
      description="Minimal self-hosted GitHub Actions Runner" \
      org.opencontainers.image.source="https://github.com/Hawaiine/minimal-runner"

# 禁止交互式配置
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 安装最小依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    sudo \
    git \
    python3 \
    python3-pip \
    python3-venv \
    locales \
    && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# 创建 runner 用户
RUN groupadd -g 1001 runner && \
    useradd -mr -d /home/runner -u 1001 -g 1001 runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 安装 GitHub Actions Runner
WORKDIR /actions-runner
COPY install-runner.sh .
RUN chmod +x install-runner.sh && ./install-runner.sh && rm install-runner.sh

# 创建工作目录
RUN mkdir -p /_work && chown -R runner:runner /_work /actions-runner

# 注入 entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown runner:runner /entrypoint.sh

USER runner
WORKDIR /actions-runner

ENTRYPOINT ["/entrypoint.sh"]