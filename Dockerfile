FROM karthrand/ubuntu-base:latest

ARG SCRIPT_PATH=/tmp/script

ENV ENV_SCRIPT_PATH=${SCRIPT_PATH}

# opencode 全局配置模板（MCP 服务 + 权限全放行，token 占位符由启动脚本注入）
COPY config/opencode.json /root/.config/opencode/opencode.json

COPY script ${SCRIPT_PATH}

RUN set -ex \
    # 安装 AI CLI 工具
    && npm install -g opencode-ai \
    # 预装通用 skill（-g -y -a opencode 装入全局公共路径，启动脚本检查自愈）
    && npx -y skills add https://github.com/karthrand/karthrand-ai-public.git -g -y --skill remote -a opencode \
    && npx -y skills add https://github.com/karthrand/karthrand-ai-public.git -g -y --skill search-web -a opencode \
    # 脚本赋权
    && chmod +x ${SCRIPT_PATH}/start.sh ${SCRIPT_PATH}/configure-opencode.sh \
    # 清理缓存
    && npm cache clean --force 2>/dev/null || true

CMD ["bash", "-c", "${ENV_SCRIPT_PATH}/start.sh"]
