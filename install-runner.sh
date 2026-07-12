#!/bin/bash -e
#
# 安装 GitHub Actions Runner
# 从 GitHub Releases 下载指定版本的 runner 二进制

GH_RUNNER_VERSION=${1:-"2.335.1"}
TARGETPLATFORM=${2:-"linux/amd64"}

export TARGET_ARCH="x64"
if [[ $TARGETPLATFORM == "linux/arm64" ]] || [[ $(uname -m) == "aarch64" ]]; then
  export TARGET_ARCH="arm64"
fi

echo "📦 下载 GitHub Actions Runner v${GH_RUNNER_VERSION} (${TARGET_ARCH})..."
curl -sL "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-${TARGET_ARCH}-${GH_RUNNER_VERSION}.tar.gz" -o actions.tar.gz

echo "📦 解压..."
tar -zxf actions.tar.gz
rm -f actions.tar.gz

echo "📦 安装依赖..."
./bin/installdependencies.sh

echo "✅ Runner 安装完成"
mkdir -p /_work