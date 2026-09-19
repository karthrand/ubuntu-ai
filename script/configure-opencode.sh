#!/bin/bash
# opencode 运行时配置生成脚本（幂等，容器每次启动执行）
# 职责：
#   1. 检查 skill（remote/search-web）是否存在，缺失时自动补装（失败不阻塞启动）
#   2. 按环境变量配置 AI 供应商（custom / deepseek / zai 可共存，默认模型优先级 custom > deepseek > zai）
#   3. 注入 MCP：GLM_MCP_TOKEN 替换占位符；context7（始终）；exa（EXA_API_KEY 有值才启用）
#   4. 将已配置变量写入 /etc/profile.d/ai-env.sh（SSH 会话不继承容器环境，此处兜底）
set -euo pipefail

readonly OPENCODE_CONFIG="/root/.config/opencode/opencode.json"
readonly OPENCODE_AUTH="/root/.local/share/opencode/auth.json"
readonly PROFILE_ENV="/etc/profile.d/ai-env.sh"
readonly SKILLS_DIR="/root/.agents/skills"
readonly SKILL_REPO="https://github.com/karthrand/karthrand-ai-public.git"

readonly DEFAULT_MODEL_DEEPSEEK="deepseek/deepseek-v4-pro"
readonly DEFAULT_MODEL_ZAI="zai-coding-plan/glm-5.3"

# 掩码输出密钥，仅用于日志摘要
mask() {
    local value=$1
    local len=${#value}
    if [ "${len}" -le 10 ]; then
        printf '****'
    else
        printf '%s****%s' "${value:0:6}" "${value: -4}"
    fi
}

# 原子写 JSON：write_json <目标文件> <jq 参数...>
write_json() {
    local target=$1
    shift
    jq "$@" "${target}" > "${target}.tmp" && mv "${target}.tmp" "${target}"
}

mkdir -p "$(dirname "${OPENCODE_CONFIG}")" "$(dirname "${OPENCODE_AUTH}")" /etc/profile.d

if [ ! -f "${OPENCODE_CONFIG}" ]; then
    echo "[configure-opencode] 缺少模板 ${OPENCODE_CONFIG}，退出" >&2
    exit 1
fi
if [ ! -f "${OPENCODE_AUTH}" ]; then
    echo '{}' > "${OPENCODE_AUTH}"
fi

default_model=""
configured=()

# ---- 1. skill 存在性检查（镜像已预装，缺失时自愈补装，失败仅告警）----
for skill in remote search-web; do
    if [ -f "${SKILLS_DIR}/${skill}/SKILL.md" ]; then
        echo "[configure-opencode] skill ${skill} 已存在，跳过"
    else
        echo "[configure-opencode] skill ${skill} 缺失，尝试补装..."
        if npx -y skills add "${SKILL_REPO}" -g -y --skill "${skill}" -a opencode; then
            echo "[configure-opencode] skill ${skill} 补装成功"
        else
            echo "[configure-opencode] skill ${skill} 补装失败（不影响启动，可稍后手动重试）" >&2
        fi
    fi
done

# ---- 2. MCP token 注入（仅存在占位符时执行，保证幂等）----
if [ -n "${GLM_MCP_TOKEN:-}" ] && grep -q '__MCP_TOKEN__' "${OPENCODE_CONFIG}"; then
    write_json "${OPENCODE_CONFIG}" --arg token "${GLM_MCP_TOKEN}" \
        'walk(if type == "string" then gsub("__MCP_TOKEN__"; $token) else . end)'
    configured+=("mcp-token")
    echo "[configure-opencode] MCP token 已注入"
fi

# ---- 3. 注入 context7 MCP（始终启用，无 key 可用；CONTEXT7_API_KEY 有值则携带）----
context7_cmd=("npx" "-y" "@upstash/context7-mcp@latest")
if [ -n "${CONTEXT7_API_KEY:-}" ]; then
    context7_cmd+=("--api-key" "${CONTEXT7_API_KEY}")
fi
write_json "${OPENCODE_CONFIG}" \
    --argjson cmd "$(printf '%s\n' "${context7_cmd[@]}" | jq -R . | jq -s .)" \
    '.mcp.context7 = {type: "local", command: $cmd, enabled: true}'
configured+=("mcp:context7")

# ---- 4. 注入 exa MCP（EXA_API_KEY 有值才启用）----
if [ -n "${EXA_API_KEY:-}" ]; then
    write_json "${OPENCODE_CONFIG}" --arg key "${EXA_API_KEY}" \
        '.mcp.exa = {type: "remote", url: ("https://mcp.exa.ai/mcp?exaApiKey=" + $key), enabled: true}'
    configured+=("mcp:exa")
else
    echo "[configure-opencode] 未设置 EXA_API_KEY，跳过 exa MCP"
fi

# ---- 5. 自定义供应商（OpenAI 兼容，三件套需同时配置）----
if [ -n "${OPENCODE_CUSTOM_BASE_URL:-}" ] && [ -n "${OPENCODE_CUSTOM_API_KEY:-}" ] && [ -n "${OPENCODE_CUSTOM_MODEL:-}" ]; then
    write_json "${OPENCODE_CONFIG}" \
        --arg url "${OPENCODE_CUSTOM_BASE_URL}" \
        --arg key "${OPENCODE_CUSTOM_API_KEY}" \
        --arg model "${OPENCODE_CUSTOM_MODEL}" \
        '.provider.custom = {
            npm: "@ai-sdk/openai-compatible",
            name: "自定义供应商",
            options: { baseURL: $url, apiKey: $key },
            models: { ($model): { name: $model } }
        }'
    default_model="custom/${OPENCODE_CUSTOM_MODEL}"
    configured+=("custom(${OPENCODE_CUSTOM_BASE_URL})")
elif [ -n "${OPENCODE_CUSTOM_BASE_URL:-}${OPENCODE_CUSTOM_API_KEY:-}${OPENCODE_CUSTOM_MODEL:-}" ]; then
    echo "[configure-opencode] OPENCODE_CUSTOM_* 需 BASE_URL/API_KEY/MODEL 三件套同时配置，本次已忽略" >&2
fi

# ---- 6. DeepSeek（opencode 官方内置供应商）----
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
    write_json "${OPENCODE_AUTH}" --arg key "${DEEPSEEK_API_KEY}" \
        '. + {deepseek: {type: "api", key: $key}}'
    if [ -z "${default_model}" ]; then
        default_model="${DEFAULT_MODEL_DEEPSEEK}"
    fi
    configured+=("deepseek(key=$(mask "${DEEPSEEK_API_KEY}"))")
fi

# ---- 7. Z.AI GLM Coding Plan（opencode 官方内置供应商）----
if [ -n "${ZAI_API_KEY:-}" ]; then
    write_json "${OPENCODE_AUTH}" --arg key "${ZAI_API_KEY}" \
        '. + {"zai-coding-plan": {type: "api", key: $key}}'
    if [ -z "${default_model}" ]; then
        default_model="${DEFAULT_MODEL_ZAI}"
    fi
    configured+=("zai-coding-plan(key=$(mask "${ZAI_API_KEY}"))")
fi

# ---- 8. 显式覆盖默认模型 ----
if [ -n "${OPENCODE_MODEL:-}" ]; then
    default_model="${OPENCODE_MODEL}"
    configured+=("model=${OPENCODE_MODEL}")
fi

if [ -n "${default_model}" ]; then
    write_json "${OPENCODE_CONFIG}" --arg model "${default_model}" '.model = $model'
fi

# ---- 9. 写入 profile.d，保证 SSH 会话可见（幂等：整文件覆盖重写）----
env_vars=(GLM_MCP_TOKEN CONTEXT7_API_KEY EXA_API_KEY OPENCODE_CUSTOM_BASE_URL OPENCODE_CUSTOM_API_KEY OPENCODE_CUSTOM_MODEL DEEPSEEK_API_KEY ZAI_API_KEY OPENCODE_MODEL)
{
    echo "# 由 configure-opencode.sh 生成（容器每次启动覆盖），勿手动编辑"
    for var in "${env_vars[@]}"; do
        if [ -n "${!var:-}" ]; then
            printf 'export %s=%q\n' "${var}" "${!var}"
        fi
    done
} > "${PROFILE_ENV}"
chmod 644 "${PROFILE_ENV}"

# ---- 10. 摘要 ----
if [ "${#configured[@]}" -gt 0 ]; then
    echo "[configure-opencode] 已配置: ${configured[*]}"
fi
if [ -n "${default_model}" ]; then
    echo "[configure-opencode] 默认模型: ${default_model}"
fi
if [ -z "${OPENCODE_CUSTOM_BASE_URL:-}${OPENCODE_CUSTOM_API_KEY:-}${OPENCODE_CUSTOM_MODEL:-}${DEEPSEEK_API_KEY:-}${ZAI_API_KEY:-}" ]; then
    cat <<'EOF'
[configure-opencode] 未检测到任何 AI 供应商配置，可选以下任意组合（配置后重启容器生效）：
  自定义供应商:  OPENCODE_CUSTOM_BASE_URL + OPENCODE_CUSTOM_API_KEY + OPENCODE_CUSTOM_MODEL
  DeepSeek:      DEEPSEEK_API_KEY
  Z.AI 编码计划: ZAI_API_KEY
  默认模型覆盖:  OPENCODE_MODEL（格式 provider/model）
EOF
fi
