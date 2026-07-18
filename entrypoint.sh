#!/bin/bash -e
#
# entrypoint.sh — 注册 GitHub Actions Runner 并启动
#
# 环境变量:
#   REPO_URL       - 仓库 URL（如 https://github.com/owner/repo）
#   ACCESS_TOKEN   - GitHub PAT（repo 权限）
#   RUNNER_NAME    - 名称（默认 hostname）
#   RUNNER_LABELS  - 标签（默认 self-hosted）
#   RUNNER_GROUP   - 组（默认 default）
#   EPHEMERAL      - 是否一次性（默认 false）
#

RUNNER_NAME=${RUNNER_NAME:-$(hostname 2>/dev/null || echo "runner")}
RUNNER_LABELS=${RUNNER_LABELS:-"self-hosted"}
RUNNER_GROUP=${RUNNER_GROUP:-"default"}
RUNNER_WORKDIR=${RUNNER_WORKDIR:-"/_work"}
EPHEMERAL=${EPHEMERAL:-"false"}
DISABLE_AUTO_UPDATE=${DISABLE_AUTO_UPDATE:-"true"}

# 检查必填变量
if [[ -z "$REPO_URL" ]]; then
  echo "❌ 必须设置 REPO_URL"
  exit 1
fi
if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "❌ 必须设置 ACCESS_TOKEN"
  exit 1
fi

# 从仓库 URL 提取 owner/name
REPO_OWNER=$(echo "$REPO_URL" | sed -E 's|https://github.com/([^/]+)/([^/]+).*|\1|')
REPO_NAME=$(echo "$REPO_URL" | sed -E 's|https://github.com/([^/]+)/([^/]+).*|\2|')

# 已注册则跳过
if [[ -f .runner ]]; then
  echo "✅ Runner 已注册，跳过配置"
else
  echo "🔧 获取 registration token..."
  REG_TOKEN=$(curl -sL -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token" \
    | jq -r '.token')

  if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
    echo "❌ 获取 registration token 失败，请检查 ACCESS_TOKEN 权限"
    exit 1
  fi

  echo "🔧 注册 Runner..."
  EPHEMERAL_FLAG=""
  [[ "$EPHEMERAL" == "true" ]] && EPHEMERAL_FLAG="--ephemeral"

  ./config.sh \
    --url "$REPO_URL" \
    --token "$REG_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --work "$RUNNER_WORKDIR" \
    --replace \
    --unattended \
    $EPHEMERAL_FLAG \
    $([[ "$DISABLE_AUTO_UPDATE" == "true" ]] && echo "--disableupdate")

  echo "✅ Runner 注册成功"
fi

# 退出时自动注销
cleanup() {
  echo "🛑 注销 Runner..."
  REMOVE_TOKEN=$(curl -sL -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/remove-token" \
    | jq -r '.token')
  ./config.sh remove --token "$REMOVE_TOKEN" 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM

echo "🚀 启动 Runner 监听..."
# 不用 exec，保留 trap 在退出时生效
./run.sh --startuptype service