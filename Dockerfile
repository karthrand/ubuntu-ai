FROM karthrand/ubuntu-base:latest

ARG SCRIPT_PATH=/tmp/script

ENV ENV_SCRIPT_PATH=${SCRIPT_PATH}

COPY script ${SCRIPT_PATH}

RUN set -ex \
    # 安装 AI CLI 工具
    && npm install -g @anthropic-ai/claude-code \
    && npm install -g @openai/codex \
    && npm install -g opencode-ai \
    && npm install -g @cometix/ccline \
    # 构建时初始化
    && chmod +x ${SCRIPT_PATH}/init.sh ${SCRIPT_PATH}/start.sh \
    && bash ${SCRIPT_PATH}/init.sh \
    # 配置 MCP 服务（构建时写入占位符，运行时由 start.sh 替换）
    && claude mcp add -s user zai-mcp-server \
        --env ANTHROPIC_AUTH_TOKEN=__MCP_TOKEN__ \
        -- npx -y "@z_ai/mcp-server" \
    && claude mcp add -s user -t http web-search-prime \
        "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp" \
        --header "Authorization: Bearer __MCP_TOKEN__" \
    && claude mcp add -s user -t http web-reader \
        "https://open.bigmodel.cn/api/mcp/web_reader/mcp" \
        --header "Authorization: Bearer __MCP_TOKEN__" \
    && claude mcp add -s user -t http zread \
        "https://open.bigmodel.cn/api/mcp/zread/mcp" \
        --header "Authorization: Bearer __MCP_TOKEN__" \
    # 清理缓存
    && npm cache clean --force 2>/dev/null || true

CMD ["bash", "-c", "${ENV_SCRIPT_PATH}/start.sh"]
