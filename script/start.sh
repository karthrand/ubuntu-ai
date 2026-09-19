#!/bin/bash
set -e

# 生成/刷新 opencode 运行时配置（AI 供应商、MCP token、SSH 环境兜底）
bash "${ENV_SCRIPT_PATH}/configure-opencode.sh"

# 启动 SSH 服务
exec /usr/sbin/sshd -D
