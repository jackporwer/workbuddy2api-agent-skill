# WorkBuddy2API Agent Skill · NAS Hub + HTTPS

**让 Agent 在极空间等 Docker NAS 上部署和维护 WorkBuddy2API Hub + 独立 Caddy HTTPS。**

这一版根据实际极空间部署整理：两个 Compose 服务、固定 HTTPS 入口、账号与用量持久化、DNS-01 自动签证书，以及只升级 Hub 的维护流程。网关实现来自 [ardeyouxipianyi/workbuddy2api-hub](https://github.com/ardeyouxipianyi/workbuddy2api-hub)，本仓库提供 Skill 和可填写的架构模板。

当前 Skill 版本为 **2026.10.16**。参考实例运行 Hub **v1.7.5**、Caddy **2.11.7** 和 DuckDNS 模块 **v0.5.0**；安装前先检查上游正式 Release 与 GHCR 实际镜像，有合适新版可直接部署，不需要等本 Skill 更新。参考版本不表示永远最新。

## 架构

```text
Agent / 客户端
    │ HTTPS：自己的 DDNS 域名，默认 TCP 7863
    ▼
Caddy + DuckDNS DNS-01 插件（https 服务）
    │ Docker 内网 HTTP
    ▼
WorkBuddy2API Hub（hub 服务，容器端口 7863）
    │
    ▼
WorkBuddy / CodeBuddy 上游
```

NAS 本机保留 `127.0.0.1:17866` 诊断入口；Hub 明文端口不直接开放公网。所有网关请求和回复仍经过 NAS，公网使用的回复会占用 NAS 上行带宽。

## 安装 Skill

在 [Releases](https://github.com/jackporwer/workbuddy2api-agent-skill/releases) 下载本版 `wb2api-nas-hub-skill-2026.10.16.zip`，将完整的 `wb2api-setup/` 放入 Agent 的 Skill 目录。也可以克隆仓库后复制 `skills/wb2api-setup/`。

DSH 可使用 `~/.dsh/skills/` 或项目中的 `.dsh/skills/`；其他 Agent 使用各自的 Skill 目录。当前 Skill 不修改你的 Agent 配置，实际部署时如需写入客户端配置会先确认。

对 Agent 说：

```text
使用 wb2api-setup，在我的极空间部署 Hub + Caddy HTTPS。
先检查 Hub 上游正式版本，使用我提供的 NAS 持久目录和域名。
已有账号、API Key、用量、端口与证书必须保留。
```

已有部署更新：

```text
使用 wb2api-setup 检查并更新 NAS 上的 Hub。
只更新 Hub，保留 HTTPS 容器、账号、Key 和证书，验证失败要能回退。
```

## 包含什么

```text
skills/wb2api-setup/
├── SKILL.md
├── references/
│   ├── deployment.md        # 新部署、接管、DDNS 与旧版迁移
│   └── operations.md        # 只升级 Hub、回退、鉴权和 SSE 验收
└── assets/nas/
    ├── docker-compose.yml  # 只有 hub + https
    ├── env.example         # 域名、端口、镜像、UID/GID，均为示例
    └── https/
        ├── Dockerfile      # 构建包含 DuckDNS 插件的 Caddy
        ├── .dockerignore   # DNS Token 与证书不进入构建上下文
        ├── Caddyfile
        └── duckdns.env.example
```

运行后数据目录为 `hub/accounts/`、`hub/usage/`、`https/data/`、`https/config/`。公开包不含任何已登录账号、API Key、DuckDNS Token、私钥、真实域名或 NAS 个人路径，也不附带桌面便携版安装包。

新部署复制 `assets/nas/` 的内容到 NAS，填写 `.env` 和 `https/duckdns.env`，按 [部署说明](skills/wb2api-setup/references/deployment.md) 准备目录与权限后启动。现有部署应由 Agent 先读取真实 Compose 再调整，不能直接覆盖。

## 保留的使用方式

| 入口 / 数据 | 规则 |
|---|---|
| `https://<域名>:<端口>/panel/` | 兼容入口，重写到 Hub 看板 |
| `/healthz` | 兼容入口，重写到 Hub `/health` |
| `/v1` | 客户端 Base URL 路径，模型 ID 使用 Hub 返回的原样名称 |
| 账号、API Key 与用量 | 保存在 Hub 持久目录中，升级保留 |
| HTTPS 证书与自动续期状态 | 独立持久保存；升级 Hub 不重建 HTTPS |

普通 Caddy 镜像没有 DuckDNS 插件。本模板通过 Dockerfile 构建，不把私人 NAS 上的 Caddy 可执行文件和证书打包发布。DNS-01 用来验证域名与签发证书；DDNS 更新、路由器入站和真实外网连通性仍需单独配置与验证。

## 验证与限制

本版已对照实际 NAS 的 Compose、Caddyfile、Caddy 模块与 Hub 健康状态整理。打包时验证 Skill 格式、Compose、Caddy 配置适配、持久化与端口结构，以及发布包内容；新的 Caddy 构建产物和用户自己的域名 / 证书需要在目标 NAS 部署后验证，不声称模板本身已经替所有环境完成签证书和真实对话。

健康检查通过不代表账号和模型调用已就绪，模型列表存在也不代表已经登录。Skill 要求分别验证账号 ready、Key 鉴权、真实对话、SSE 和外网连接。网络重置与上游 429 分层处理，不把单台电脑的 IPv6 失败推断为 NAS 故障。

## 旧 Panel 版

2026.10.14 的 Panel 版及五平台备用包保存在 [legacy/panel/](legacy/panel/README.md)，原 Release 仍可下载。它基于 `linguo2625469/workbuddy2api-panel`，与当前 Hub 版配置和凭据格式不同。不要把旧目录直接改名当成 Hub 迁移。

来源见 [NOTICE.md](NOTICE.md)，许可见 [LICENSE](LICENSE)。本项目是第三方部署封装，使用自己的授权账号并遵守原项目和上游服务的使用规则。
