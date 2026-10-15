---
name: wb2api-setup
description: 在极空间或其他 Docker NAS 上部署、接管和维护 WorkBuddy2API Hub 与独立 Caddy HTTPS，保留账号、API Key、用量、端口和证书，验证真实模型与 SSE 调用。适用于“部署 NAS 网关”“把极空间 Hub 架构装起来”“升级 Hub 保留 HTTPS”，不用于桌面便携版安装。
metadata:
  version: "2026.10.16"
  architecture: "nas-hub-caddy-duckdns"
  reference-hub-version: "v1.7.5"
---

# NAS Hub + Caddy HTTPS

将用户自有 WorkBuddy / CodeBuddy 账号接入 NAS 网关。此 Skill 封装已经在极空间运行的双服务架构，不重新实现网关。Hub 来自 https://github.com/ardeyouxipianyi/workbuddy2api-hub 。安装时先检查上游正式 Release 和 GHCR 实际镜像，不能把参考版本 v1.7.5 当成永远最新。

## 架构与不可覆盖的数据

```text
Agent / 客户端 → DDNS 域名:HTTPS端口 → Caddy → hub:7863 → 上游
NAS 本机诊断 → 127.0.0.1:17866 → hub:7863
```

- Compose 服务只有 `hub`、`https`；外部默认 HTTPS TCP 7863，Hub 诊断端口仅绑定回环。
- `hub/accounts/` 保存账号和设置（包括 API Key、面板密码）；`hub/usage/` 保存用量。
- `https/data/` 保存 ACME 证书、私钥和续期状态；`https/config/` 保存 Caddy 运行配置。
- `/panel`、`/panel/` 重写到 Hub `/`，`/healthz` 重写到 `/health`；模型 ID 原样读取 `/v1/models`，不套用旧 Panel 的 `cn:` 前缀。
- 用户提供的主机、SSH 凭据、DNS Token 与 API Key 只用于其部署，不进入仓库、日志、发行包或公开截图。

先阅读 [部署与接管](references/deployment.md)。更新或排障时再阅读 [维护与验证](references/operations.md)。可复制的模板位于 `assets/nas/`。

## 1. 识别环境与部署模式

复用用户已经提供的信息，检查 NAS CPU 架构、Docker / Compose、可写持久目录、现有服务、映射端口和实际挂载。Windows 执行管理命令前确认 `$PSVersionTable` 与 `(Get-Process -Id $PID).Path`，复用已有 PowerShell 7。

- **新部署**：确认用户自己的域名、HTTPS 端口、DNS 提供商与 DNS-01 凭据是否具备。默认模板用 DuckDNS；其他 DNS 供应商需要对应 Caddy 插件，不能只换 Token 名。
- **已有 Hub + HTTPS**：读取现有 Compose、容器镜像摘要、挂载与 Caddyfile，保留当前目录、入口、证书与凭据。模板不是覆盖现有运行配置的命令。
- **旧 Panel → Hub**：这是数据格式迁移，先预览 Hub 对旧凭据的导入结果，备份后再转换；不能只把旧 `auths/` 重命名为 `accounts/`。账号数、实际授权与 API Key 验证通过之前不切换入口，不清理旧数据。

只问缺失且影响部署的信息。没有公网入站能力时应明确说明，先提供私网入口；DDNS 和证书不能替代端口转发、IPv6 入站或可达网络。

## 2. 选择并固定上游版本

查询原项目 `/releases/latest`、正式 Release 说明与 GHCR 镜像。拉取所选版本后，记录 `RepoDigests`、`org.opencontainers.image.version` 和 revision，确认对应发布与 NAS 架构，再将解析到的不可变摘要写入本地 `.env` 的 `HUB_IMAGE`。

如果 Release、`latest` 标签与镜像版本不同步，不按 `latest` 名称猜版本，不自动降级。参考模板固定的是经过部署验证的 v1.7.5；检查失败可以明确使用参考摘要，但不得称为最新。

Caddy 参考运行时为 2.11.7，DuckDNS 模块为 v0.5.0。标准 Caddy 镜像不自带该插件：新部署使用 `assets/nas/https/Dockerfile` 构建，运行 `caddy list-modules` 验证 `dns.providers.duckdns`。已有 NAS 使用挂载的自定义 Caddy 可执行文件时，先核对它的模块和架构，不擅自替换。

## 3. 准备与启动

新部署复制 `assets/nas/` 到用户选定的持久目录，复制 `env.example` 为 `.env`、`https/duckdns.env.example` 为 `https/duckdns.env`，按环境填写域名、端口、镜像、UID/GID。DNS Token 不作为构建参数。生成运行目录并让容器 UID 可写，设置凭据文件权限。

先 `docker compose config --quiet`，再构建 Caddy 并验证模块和配置，最后启动两个服务。模板没有 Docker socket 挂载。DNS-01 不要求开放 80/443 签证书，但实际 HTTPS 端口仍要可达；地址更新由 NAS DDNS 维护，不是 Caddy 自动维护 A/AAAA。

已有部署仅进行任务所需的变更。Hub 更新使用 `up -d --no-deps hub`，不顺带重建 HTTPS。保存旧摘要、Compose 与私有数据备份，失败按已验证的回退方法恢复。

## 4. 账号与客户端

让用户在可达的 `/panel/` 面板登录并添加自己的账号；NAS 无需图形界面。首次公网交付前修改默认面板密码并确认 API 必须鉴权。不可把 API Key 和 DNS Token 混用。

用 `/health` 的 `accounts` 与 `accounts_ready`、面板账号状态和真实对话共同判断账号可用性。`/v1/models` 是模型目录，存在模型不代表账号已经登录或可用。

配置客户端前先确认用户同意，备份并核对当前客户端确实支持的协议 / 配置格式；不得盲写配置文件。交付 Base URL 为 `https://<用户域名>:<端口>/v1`，模型使用实际测试通过的 ID。避免重复追加 `/v1`。

## 5. 验收与交付

按 operations.md 分层检查：Hub 健康、账号就绪、Caddy / 证书、API 鉴权、普通对话、SSE、外网连接。没有账号或触发 429 时如实标注模型验证未完成，不能用 HTTP 200 健康检查代替端到端通过。

报告实际 Hub 版本 / 摘要、HTTPS 地址、账号数量（不含凭据）、测试结果与未完成项、私有备份位置和回退方式。明确 NAS 必须保持联网运行；所有通过网关的请求与回复仍经过 NAS。

## 维护边界

升级仅替换目标服务的程序 / 镜像，保留账号、Key、用量和证书；不自动 prune、不删除旧项目备份、不修改路由器或其他 NAS 服务。公网 RST、DNS / TLS 失败与上游 429 分开诊断，不能因当前电脑没有 IPv6 出口就断定服务器 IPv6 故障。
