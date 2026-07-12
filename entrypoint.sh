#!/bin/bash -e
#
# 工作流执行入口 — 注册 runner 并启动监听
# 支持 PAT 或 GitHub App Token 两种认证方式

CONFIG_URL=""
ACCESS_TOKEN=""
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}
RUNNER_LABELS=${RUNNER_LABELS:-"self-hosted"}
RUNNER_GROUP=${RUNNER_GROUP:-"default"}
RUNNER_WORKDIR=${RUNNER_WORKDIR:-"/_work"}
REPO_URL=${REPO_URL:-""}
ORG_URL=${ORG_URL:-""}
# 优先使用 App Token，其次 PAT
APP_TOKEN=${APP_TOKEN:-""}
EPHEMERAL=${EPHEMERAL:-"false"}
DISABLE_AUTO_UPDATE=${DISABLE_AUTO_UPDATE:-"true"}

# 确定注册目标
if [[ -n "$REPO_URL" ]]; then
  CONFIG_URL="--url $REPO_URL"
elif [[ -n "$ORG_URL" ]]; then
  CONFIG_URL="--url $ORG_URL"
else
  echo "❌ 必须设置 REPO_URL 或 ORG_URL"
  exit 1
fi

# 获取 token
if [[ -n "$APP_TOKEN" ]]; then
  echo "🔑 使用 GitHub App Token"
  ACCESS_TOKEN="$APP_TOKEN"
elif [[ -n "$ACCESS_TOKEN" ]]; then
  echo "🔑 使用 Personal Access Token"
else
  echo "❌ 必须设置 ACCESS_TOKEN 或 APP_TOKEN"
  exit 1
fi

# 已注册则跳过
if [[ -f .runner ]]; then
  echo "✅ Runner 已注册，跳过配置"
else
  echo "🔧 注册 Runner..."
  ./config.sh \
    $CONFIG_URL \
    --token "$ACCESS_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --work "$RUNNER_WORKDIR" \
    --replace \
    --unattended \
    $([[ "$DISABLE_AUTO_UPDATE" == "true" ]] && echo "--disableupdate")

  echo "✅ Runner 注册成功"
fi

# 处理退出信号
cleanup() {
  echo "🛑 注销 Runner..."
  ./config.sh remove --token "$ACCESS_TOKEN" 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM

echo "🚀 启动 Runner 监听..."
./run.sh --startuptype service