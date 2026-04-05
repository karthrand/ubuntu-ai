#!/bin/bash
set -e

# 配置 Claude Code 状态栏（ccline）
mkdir -p /root/.claude
ccline --init 2>/dev/null || true
if [ -f /root/.claude/settings.json ]; then
    jq '. + {"statusLine": {"type": "command", "command": "/root/.claude/ccline/ccline", "padding": 0}}' \
        /root/.claude/settings.json > /tmp/settings_tmp.json && \
        mv /tmp/settings_tmp.json /root/.claude/settings.json
else
    echo '{"statusLine": {"type": "command", "command": "/root/.claude/ccline/ccline", "padding": 0}}' \
        > /root/.claude/settings.json
fi

# 配置 claude alias（跳过权限确认）
grep -q 'IS_SANDBOX=1' /root/.bashrc 2>/dev/null || \
    echo 'export IS_SANDBOX=1' >> /root/.bashrc
grep -q 'alias claude=' /root/.bashrc 2>/dev/null || \
    echo 'alias claude='\''claude --dangerously-skip-permissions'\''' >> /root/.bashrc
