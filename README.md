# minimal-runner

<p align="center">
  <img src="https://img.shields.io/badge/基础-debian:bookworm--slim-blue" alt="Base">
  <img src="https://img.shields.io/badge/Python-3.11-green" alt="Python">
  <img src="https://img.shields.io/badge/安全-无Docker--in--Docker-brightgreen" alt="Security">
  <img src="https://img.shields.io/badge/架构-amd64|arm64-lightgrey" alt="Arch">
</p>

**轻量级 GitHub Actions 自建 Runner** — 只跑任务，不跑 Docker。

与 [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner) 相比：

| 特性 | myoung34 | minimal-runner |
|------|----------|----------------|
| 镜像大小 | ~1.5GB | ~500MB |
| Docker-in-Docker | ✅ 默认开启 | ❌ 不包含 |
| 攻击面 | 大（挂载 docker.sock） | 小（纯 runner） |
| 预装工具 | 大量 build 工具 | 仅 Python3 + Git + curl |
| 启动时间 | 慢 | 快 |

---

## 📋 使用步骤

### 1️⃣ 生成 GitHub Token

打开 https://github.com/settings/tokens → **Generate new token (classic)**

| 字段 | 值 |
|------|-----|
| Note | `minimal-runner` |
| Expiration | 选 **No expiration**（或 90 天，到期续） |
| Scopes | 勾选 **`repo`**（全选） |

点击 **Generate token**，复制生成的 `ghp_` 开头的字符串。

> ⚠️ 这是你的 Runner 的身份凭证，不要泄露、不要提交到 git。

### 2️⃣ 快速启动（Docker Compose，推荐）

```bash
# 1. 创建项目目录
mkdir -p ~/minimal-runner && cd ~/minimal-runner

# 2. 下载 docker-compose.yml
curl -sL https://raw.githubusercontent.com/Hawaiine/minimal-runner/main/docker-compose.yml -o docker-compose.yml

# 3. 创建 .env 文件（填入第1步生成的 token）
cat > .env << EOF
ACCESS_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
REPO_URL=https://github.com/Hawaiine/iptv-sources
RUNNER_NAME=my-runner
RUNNER_LABELS=self-hosted,iptv
EOF

# 4. 启动
docker compose up -d

# 5. 查看日志
docker compose logs -f
```

看到以下日志表示注册成功：

```
✅ Runner 注册成功
🚀 启动 Runner 监听...
```

### 3️⃣ 快速启动（Docker run）

```bash
docker run -d --restart unless-stopped \
  --name minimal-runner \
  -e REPO_URL=https://github.com/Hawaiine/iptv-sources \
  -e ACCESS_TOKEN=ghp_xxxxxxxxxxxx \
  -e RUNNER_NAME=my-runner \
  -e RUNNER_LABELS=self-hosted,iptv \
  ghcr.io/hawaiine/minimal-runner:latest
```

### 4️⃣ 验证 Runner 在线

打开仓库页面：**Settings → Actions → Runners**

你应该能看到 `my-runner` 显示 **Idle** 状态。

---

## 🔧 配置说明

### 环境变量

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `REPO_URL` | ✅ | — | GitHub 仓库 URL（如 `https://github.com/owner/repo`） |
| `ACCESS_TOKEN` | ✅ | — | GitHub PAT（repo 权限） |
| `RUNNER_NAME` | — | 容器 hostname | Runner 显示名称 |
| `RUNNER_LABELS` | — | `self-hosted` | 逗号分隔的标签，用于 workflow 定向 |
| `RUNNER_GROUP` | — | `default` | Runner 组 |
| `EPHEMERAL` | — | `false` | 是否一次性（跑完即注销） |
| `DISABLE_AUTO_UPDATE` | — | `true` | 禁用自动更新（减少重启） |

### 多区域部署示例

```yaml
# docker-compose.yml — 部署多个 Runner，不同区域
services:
  runner-wuhan:
    image: ghcr.io/hawaiine/minimal-runner:latest
    restart: unless-stopped
    environment:
      REPO_URL: https://github.com/Hawaiine/iptv-sources
      ACCESS_TOKEN: ${ACCESS_TOKEN}
      RUNNER_NAME: iptv-wuhan
      RUNNER_LABELS: self-hosted,iptv,region-wuhan

  runner-guangdong:
    image: ghcr.io/hawaiine/minimal-runner:latest
    restart: unless-stopped
    environment:
      REPO_URL: https://github.com/Hawaiine/iptv-sources
      ACCESS_TOKEN: ${ACCESS_TOKEN}
      RUNNER_NAME: iptv-guangdong
      RUNNER_LABELS: self-hosted,iptv,region-guangdong
```

---

## 🏗 项目结构

```
minimal-runner/
├── Dockerfile            # 镜像构建文件
├── entrypoint.sh         # 容器入口：注册 + 启动 runner
├── install-runner.sh     # 下载安装 GitHub Actions Runner 二进制
├── docker-compose.yml    # Compose 示例
├── .env.example          # 环境变量模板
└── README.md
```

## 🔐 安全说明

1. **无 Docker-in-Docker** — 不安装 Docker CLI，不挂载 `/var/run/docker.sock`，即使 workflow 被恶意篡改也无法通过 runner 接触到宿主机 Docker 守护进程。

2. **非 root 运行** — runner 进程以 `runner` 用户（UID 1001）运行，不是 root。

3. **最小依赖** — 镜像只包含：
   - GitHub Actions Runner 官方二进制
   - Python 3 + pip（运行 Python 脚本）
   - Git（检出仓库）
   - curl + jq（注册流程）

4. **定期更新** — 关注 GitHub Actions Runner [release notes](https://github.com/actions/runner/releases) 更新镜像版本。

## 🛠 本地构建

```bash
git clone https://github.com/Hawaiine/minimal-runner.git
cd minimal-runner

# 构建
docker build -t minimal-runner .

# 运行
docker run -d --restart unless-stopped \
  --name my-runner \
  -e REPO_URL=https://github.com/your/repo \
  -e ACCESS_TOKEN=ghp_xxxx \
  minimal-runner
```

## 📦 发布到 GitHub Container Registry

项目已配置 GitHub Actions 自动构建，推送 tag 即可自动发布：

```bash
git tag v1.0.0
git push origin v1.0.0
```

或者手动发布：

```bash
docker build -t ghcr.io/hawaiine/minimal-runner:latest .
docker push ghcr.io/hawaiine/minimal-runner:latest
```

---

<p align="center">
  <sub>纯净 · 轻量 · 安全 · 专为国内 IPTV 测活设计</sub>
</p>