# WorkBuddy2API Agent Skill

**把 WorkBuddy2API 的部署流程做成 Skill，方便在 DSH 和其他支持 Skill 的 Agent 中直接使用。**

本项目基于 [linguo2625469/workbuddy2api-panel](https://github.com/linguo2625469/workbuddy2api-panel) 制作。实际模型网关、Web 管理面板、账号登录和转发能力均来自原项目；本仓库提供 Agent 部署指引、已校验的备用安装包，以及 NAS 部署材料。

> **安装优先跟随原项目版本。** Agent 安装前先查看原项目最新正式 Release，下载对应平台的安装包与同版本校验文件，校验后直接部署新版。附带的 v1.13.0 二进制是离线 / 下载受限时的备用资源，不会把用户固定在这个版本。

## 在 Agent 中使用

在仓库的 **Releases** 下载 `wb2api-skill-2026.10.14.zip`，解压后将完整的 `wb2api-setup/` 文件夹放入 Agent 的 Skill 目录；也可以下载本仓库，再复制 `skills/wb2api-setup/`。DSH 用户可放入 `~/.dsh/skills/`，或当前项目的 `.dsh/skills/`。不要只复制 `SKILL.md`，备用安装包与模板也需要保留。

然后对 Agent 说：

```text
使用 wb2api-setup 帮我安装 WorkBuddy2API。
先检查原项目的最新正式版本，有新版就直接部署新版。
我使用本机客户端，暂时不需要公网入口。
```

Agent 会检查环境和原项目版本、校验安装包、生成独立 API Key、启动网关，再引导你通过面板登录自己的 CodeBuddy 账号。完成后，它会选择实际可用模型、验证一次对话，并交付：

```text
Base URL：网关的实际访问地址，例如 http://127.0.0.1:7863/v1
API Key：安装时生成的密钥
模型名：从网关模型列表获取并实际测试成功的模型 ID
```

完整步骤见 [DSH / Agent 安装说明](guides/agent-skill.md)，执行入口为 [SKILL.md](skills/wb2api-setup/SKILL.md)。也可以先让 Agent 阅读本仓库的 Skill，再按你的平台与使用场景执行。

## 版本选择

| 情况 | Agent 的处理 |
|---|---|
| 原项目有更新的正式 Release | 使用新版对应平台安装包和该版本 checksums.txt，校验后部署 |
| 原项目最新版本与备用包一致 | 可复用已校验的附带包，避免重复下载 |
| 无法检查版本或下载受限 | 明确告知使用附带 v1.13.0，不声称它是最新版 |
| 最新版缺少平台包或校验文件 | 说明限制；不能跳过校验或使用另一个版本的校验文件 |
| 已有正常运行的网关 | 保留账号、配置和状态；确需升级时备份旧二进制，升级后验证，失败回滚 |

Skill 版本与网关版本分开维护。当前 Skill 为 **2026.10.14**，备用网关包为 **v1.13.0**。网关版本来源为 [原项目 Releases](https://github.com/linguo2625469/workbuddy2api-panel/releases)，模型能力与账号额度以实际运行结果为准。

## 附带资源与来源

```text
skills/wb2api-setup/
├── SKILL.md                       # Agent 安装与维护流程
├── templates/config.json          # 备用 v1.13.0 配置，密钥是占位符
└── resources/
    ├── checksums.txt              # 原项目 v1.13.0 安装包校验清单
    └── 五个平台的 v1.13.0 安装包

deploy/nas/
├── docker-compose.yml             # 使用原项目 GHCR 镜像的 NAS 示例
├── config.example.json            # 基于原项目配置样例，密钥是占位符
├── Dockerfile                     # 将原项目 Release 二进制构建为本地镜像
└── build.ps1                      # 自动检查版本、校验、构建并导出镜像

guides/
├── agent-skill.md
└── nas-deployment.md
```

备用包支持 Windows x64、macOS Intel / Apple Silicon、Linux amd64 / arm64。五个平台压缩包共约 16.1 MiB。它们来自原项目 Release；本仓库没有重新实现网关，也没有修改这些二进制。

NAS Compose、配置样例、镜像构建材料同样基于原项目整理。Docker / NAS 部署仍运行原项目的网关，不是另一套代理。详细对应关系见 [来源说明](NOTICE.md)。

## 部署到 NAS

见 [NAS 部署与网络说明](guides/nas-deployment.md)。可以直接使用原项目 GHCR 镜像，也可以用 `deploy/nas/build.ps1` 从原项目最新正式 Release 构建镜像，再导入 NAS。

```powershell
# 先显示当前 PowerShell 版本与运行路径，优先使用已有 PowerShell 7
$PSVersionTable.PSVersion
(Get-Process -Id $PID).Path

# 自动检查原项目最新正式 Release；默认构建 Linux amd64 镜像
./deploy/nas/build.ps1

# ARM NAS
./deploy/nas/build.ps1 -Architecture arm64

# 仅准备并校验文件，不启动 Docker 构建
./deploy/nas/build.ps1 -PrepareOnly
```

NAS 会转发模型请求与回复：`客户端 ↔ NAS ↔ 原项目配置的上游服务`。在家直接用局域网地址时，NAS 到电脑的回复走局域网；外网使用时，家宽上行还承担回复转发。低并发文本使用不一定需要很高带宽，大上下文和并发任务应按实际上传速度判断。

## 公网、账号与配置

默认先使用本机或私有网络地址。需要云端 Agent 访问时，再配置 HTTPS 入口并实际验证流式输出。Cloudflare **Quick Tunnel 不支持 SSE**，只能用于接受其限制的临时非流式测试；不能仅凭健康检查成功就交付给流式客户端。参见 [Cloudflare 官方限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)。

本仓库不包含任何可直接使用的账号、实际 API Key 或已授权 Agent 配置。安装时使用你自己的账号，凭据由实际部署机器保存；`auths/`、运行状态、浏览器数据和实际 `config.json` 不属于发布材料。使用范围与服务条款请阅读原项目说明。

## 反馈与许可

- Skill 安装步骤、打包、NAS 材料的问题：在本仓库反馈。
- 网关功能、面板、模型转发或账号接口的问题：先检查原项目的最新说明与 Release，必要时反馈给原项目。
- 原项目基于 MIT License。本仓库保留其版权与许可声明，详见 [LICENSE](LICENSE) 和 [NOTICE.md](NOTICE.md)。
