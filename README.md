# ubuntu-ai

基于 ubuntu-base 的 AI 开发环境镜像，集成主流 AI CLI 工具及 MCP 服务。

## 包含内容

在 ubuntu-base 基础上新增：

- **AI CLI 工具**：Claude Code、Codex、OpenCode、CCometixLine
- **MCP 服务**：zai-mcp-server、web-search-prime、web-reader、zread

继承自 ubuntu-base：

- **Node.js 24** + npm（阿里云镜像）
- **Python 3** + pip + uv（阿里云镜像）
- **SSH 服务**：端口 2222
- **系统工具**：curl、wget、vim、git、jq 等

## 镜像源

| 类型 | 源地址 |
|------|--------|
| apt | 阿里云 mirrors.aliyun.com（继承自基础镜像） |
| pip | 阿里云 mirrors.aliyun.com/pypi/simple/（继承自基础镜像） |
| npm | 阿里云 registry.npmmirror.com（继承自 基础镜像） |

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
# 编辑 .env 填入 GLM_API_KEY 和 GLM_MCP_TOKEN
docker compose up -d

# SSH 连接
ssh root@localhost -p 2222

# 交互式运行
docker run -it --rm \
  -e ANTHROPIC_AUTH_TOKEN=your_api_token \
  -e GLM_AUTH_TOKEN=your_mcp_token \
  ubuntu-ai
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_AUTH_TOKEN` | Claude Code API 令牌 |
| `GLM_AUTH_TOKEN` | MCP 服务认证令牌 |
| `ANTHROPIC_BASE_URL` | API 代理地址 |
| `ANTHROPIC_MODEL` | 使用的模型 |

## 目录结构

```
.
├── Dockerfile
├── docker-compose.yml.tmp
├── script/
│   ├── init.sh      # 构建时初始化
│   └── start.sh     # 容器启动脚本
└── .github/
    └── workflows/
        └── build.yml
```
