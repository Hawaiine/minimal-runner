#!/bin/bash -e
#
# 安装 GitHub Actions Runner
# 从 GitHub API 获取最新版 runner 二进制
#

TARGETPLATFORM=${1:-"linux/amd64"}

export TARGET_ARCH="x64"
if [[ $TARGETPLATFORM == "linux/arm64" ]] || [[ $(uname -m) == "aarch64" ]]; then
  export TARGET_ARCH="arm64"
fi

echo "🔍 获取最新 Runner 版本..."
GH_RUNNER_VERSION=$(curl -sL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/actions/runner/releases/latest" \
  | jq -r '.tag_name' | sed 's/^v//')

if [[ -z "$GH_RUNNER_VERSION" || "$GH_RUNNER_VERSION" == "null" ]]; then
  echo "⚠️ 获取版本失败，使用默认版本 2.322.0"
  GH_RUNNER_VERSION="2.322.0"
fi

echo "📦 下载 GitHub Actions Runner v${GH_RUNNER_VERSION} (${TARGET_ARCH})..."
curl -sL \
  "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-${TARGET_ARCH}-${GH_RUNNER_VERSION}.tar.gz" \
  -o actions.tar.gz

echo "📦 解压..."
tar -zxf actions.tar.gz
rm -f actions.tar.gz

echo "📦 安装依赖..."
./bin/installdependencies.sh

echo "✅ Runner v${GH_RUNNER_VERSION} 安装完成"
mkdir -p /_work