# ubuntu-ai

基于 ubuntu-base 的 AI 开发环境镜像，以 OpenCode 为主力 AI CLI，并集成 MCP 服务。

## 包含内容

在 ubuntu-base 基础上新增：

- **AI CLI 工具**：OpenCode
- **MCP 服务**：zai-mcp-server、web-search-prime、web-reader、zread

继承自 ubuntu-base：

- **Node.js 24** + npm（阿里云镜像）
- **Python 3** + pip + uv（阿里云镜像）
- **SSH 服务**：端口 2222
- **系统工具**：curl、wget、vim、git、jq 等

## AI 供应商配置

容器启动时由 `configure-opencode.sh` 按环境变量自动生成 opencode 配置（幂等，改配置后重启容器即可生效），三种模式可任意组合共存：

### 模式一：自定义供应商（任意 OpenAI 兼容 API）

| 变量 | 说明 |
|------|------|
| `OPENCODE_CUSTOM_BASE_URL` | API 地址（如 `https://api.example.com/v1`） |
| `OPENCODE_CUSTOM_API_KEY` | API 密钥 |
| `OPENCODE_CUSTOM_MODEL` | 默认模型 ID（三件套需同时配置，缺一忽略） |

### 模式二：DeepSeek（opencode 官方内置）

| 变量 | 说明 |
|------|------|
| `DEEPSEEK_API_KEY` | DeepSeek API 密钥（默认模型 `deepseek/deepseek-v4-pro`） |

### 模式三：Z.AI GLM Coding Plan（opencode 官方内置）

| 变量 | 说明 |
|------|------|
| `ZAI_API_KEY` | Z.AI Coding Plan API 密钥（默认模型 `zai-coding-plan/glm-5.3`） |

### 通用

| 变量 | 说明 |
|------|------|
| `OPENCODE_MODEL` | 显式覆盖默认模型（格式 `provider/model`，优先级最高） |
| `GLM_MCP_TOKEN` | MCP 服务认证令牌 |

默认模型优先级：`OPENCODE_MODEL` > custom > deepseek > zai。

## MCP 服务

| 名称 | 类型 | 端点 |
|------|------|------|
| zai-mcp-server | local (stdio) | `npx -y @z_ai/mcp-server` |
| web-search-prime | remote | `https://open.bigmodel.cn/api/mcp/web_search_prime/mcp` |
| web-reader | remote | `https://open.bigmodel.cn/api/mcp/web_reader/mcp` |
| zread | remote | `https://open.bigmodel.cn/api/mcp/zread/mcp` |

remote 服务通过 `Authorization: Bearer <GLM_MCP_TOKEN>` 认证，容器启动时自动注入。

## 镜像源

| 类型 | 源地址 |
|------|--------|
| apt | 阿里云 mirrors.aliyun.com（继承自基础镜像） |
| pip | 阿里云 mirrors.aliyun.com/pypi/simple/（继承自基础镜像） |
| npm | 阿里云 registry.npmmirror.com（继承自基础镜像） |

## 构建

```bash
# 构建（当前架构）
docker build -t ubuntu-ai .

# 指定架构
docker build --build-arg TARGETARCH=arm64 -t ubuntu-ai:arm64 .
```

## 使用

```bash
# Docker Compose 部署
cp docker-compose.yml.tmp docker-compose.yml
cp .env.tmp .env
# 编辑 .env 按需填入 API Key 与 MCP 令牌
docker compose up -d

# SSH 连接
ssh root@localhost -p 2222

# 交互式运行（单次）
docker run -it --rm \
  -e ZAI_API_KEY=your_api_key \
  -e GLM_MCP_TOKEN=your_mcp_token \
  ubuntu-ai
```

SSH 登录后已配置的供应商密钥会通过 `/etc/profile.d/ai-env.sh` 自动注入会话环境，直接运行 `opencode` 即可使用；权限已配置为全放行（`permission: allow`）。

## 目录结构

```
.
├── Dockerfile
├── config/
│   └── opencode.json          # opencode 全局配置模板（MCP + 权限）
├── docker-compose.yml.tmp
├── .env.tmp
├── script/
│   ├── configure-opencode.sh  # 运行时配置生成（供应商 + MCP token + SSH 环境兜底）
│   └── start.sh               # 容器启动脚本
└── .github/
    └── workflows/
        └── build.yml
```

## 运行时配置原理

```
容器启动
  └─ start.sh
       ├─ configure-opencode.sh（幂等）
       │    ├─ custom/deepseek/zai 密钥 → /root/.local/share/opencode/auth.json + opencode.json
       │    ├─ GLM_MCP_TOKEN → 替换 opencode.json 中占位符
       │    └─ 已配置变量 → /etc/profile.d/ai-env.sh
       └─ exec sshd -D
```

选择落盘而非运行时环境变量：SSH 会话默认不继承容器环境变量，落盘（auth.json / 实值替换）+ profile.d 双保险确保 SSH 与 `docker exec` 场景均可正常使用。
