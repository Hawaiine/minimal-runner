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
  echo "ERROR: REPO_URL not set"
  exit 1
fi
if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "ERROR: ACCESS_TOKEN not set"
  exit 1
fi

# 从仓库 URL 提取 owner/name
REPO_OWNER=$(echo "$REPO_URL" | sed -E 's|https://github.com/([^/]+)/([^/]+).*|\1|')
REPO_NAME=$(echo "$REPO_URL" | sed -E 's|https://github.com/([^/]+)/([^/]+).*|\2|')

# 已注册则跳过
if [[ -f .runner ]]; then
  echo "Runner already registered, skipping config"
else
  echo "Fetching registration token..."
  REG_TOKEN=$(curl -sL -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token" \
    | jq -r '.token')

  if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
    echo "Failed to get registration token - check ACCESS_TOKEN permissions"
    exit 1
  fi

  echo "Registering runner..."
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

  echo "Runner registered successfully"
fi

# 退出时自动注销
cleanup() {
  echo "Unregistering runner..."
  REMOVE_TOKEN=$(curl -sL -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/remove-token" \
    | jq -r '.token')
  ./config.sh remove --token "$REMOVE_TOKEN" 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM

echo "Starting runner listener..."
# 不用 exec，保留 trap 在退出时生效
./run.sh --startuptype service