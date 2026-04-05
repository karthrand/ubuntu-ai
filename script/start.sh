#!/bin/bash
set -e

# 替换 MCP 配置中的 token 占位符
if [ -n "$GLM_AUTH_TOKEN" ] && [ -f /root/.claude.json ]; then
    jq --arg token "$GLM_AUTH_TOKEN" \
        'walk(if type == "string" then gsub("__MCP_TOKEN__"; $token) else . end)' \
        /root/.claude.json > /tmp/claude_tmp.json && \
        mv /tmp/claude_tmp.json /root/.claude.json
fi

# 启动 SSH 服务
exec /usr/sbin/sshd -D
