# 用 DSH / AI 助手部署 wb2api

本仓库附带 `wb2api-setup` Skill。它指导助手安装网关、校验文件、引导你登录自己的 CodeBuddy 账号，并输出客户端需要的 Base URL、API Key 和模型名。Skill 是部署说明与资源包，不是模型服务本身；服务仍运行在你选择的机器上。

本 Skill 基于 [原项目 workbuddy2api-panel](https://github.com/linguo2625469/workbuddy2api-panel) 制作。当前 Skill 版本为 **2026.10.14**，备用安装包固定为 **v1.13.0**。每次安装先检查 [原项目 Releases](https://github.com/linguo2625469/workbuddy2api-panel/releases)，有新版时直接部署对应平台的最新正式版；备用包用于同版本复用或网络受限时回退。安装包与 checksums.txt 必须属于同一版本。

## 包含哪些文件

```text
skills/wb2api-setup/
├── SKILL.md
├── templates/config.json       # API Key 为 __API_KEY__ 占位符
└── resources/
    ├── checksums.txt
    ├── wb2api-panel-v1.13.0-windows-amd64.zip
    ├── wb2api-panel-v1.13.0-darwin-amd64.tar.gz
    ├── wb2api-panel-v1.13.0-darwin-arm64.tar.gz
    ├── wb2api-panel-v1.13.0-linux-amd64.tar.gz
    └── wb2api-panel-v1.13.0-linux-arm64.tar.gz
```

五个平台的备用压缩包共约 16.1 MiB。安装前会对压缩包做 SHA256 校验。若选择内嵌版本，无需重新下载这些包；若原项目已更新，Agent 从该新版 Release 获取安装包和校验文件。版本查询、账号登录、模型调用和可选公网入口仍需要网络。

## 安装到 DSH

先克隆仓库，或在 GitHub 的 **Code → Download ZIP** 下载后解压。复制整个 `skills/wb2api-setup/` 文件夹，不能只复制 `SKILL.md`，否则会缺少安装包和配置模板。

DSH 默认可发现以下位置的 Skill：

| 范围 | 安装位置 |
|---|---|
| 当前项目 | `<项目目录>/.dsh/skills/wb2api-setup/` |
| 当前项目的共享 Agent 目录 | `<项目目录>/.agents/skills/wb2api-setup/` |
| 当前用户 | `~/.dsh/skills/wb2api-setup/` |
| 当前用户的共享 Agent 目录 | `~/.agents/skills/wb2api-setup/` |

如果设置了 `DSH_HOME`，用户目录以它的 `skills/` 子目录为准；也可以使用 DSH 的 `customSkillDirs` 指向本仓库的 `skills/`。目录规则参考 [DSH 官方文件系统 Skill 文档](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/skill/skill-filesystem/README.zh.md)。

例如，在仓库根目录用 PowerShell 复制到用户默认目录：

```powershell
$skillRoot = Join-Path $HOME '.dsh/skills'
New-Item -ItemType Directory -Path $skillRoot -Force | Out-Null
Copy-Item -LiteralPath './skills/wb2api-setup' -Destination $skillRoot -Recurse
```

若目标已经存在，先备份旧 Skill，再替换为本版。安装后确认助手能发现 `wb2api-setup`；发现失败时检查当前 DSH 配置是否启用了文件系统 Skill 提供方，以及目录结构是否多套了一层。

## 对助手说什么

```text
使用 wb2api-setup，帮我在这台电脑安装 wb2api。
先检查原项目的最新正式版本，有新版就直接部署新版。
我使用本机客户端，先用本机地址，不需要公网入口。
```

助手会先检查原项目 Release，选择对应平台的资源包、校验并安装、生成独立 API Key、启动服务，然后提供面板地址。安装新版时以该版的配置样例为准，避免使用过期配置。你在浏览器中完成账号登录即可。账号就绪后，助手检查实际模型列表并测试一次对话。

如果使用端是云端 SaaS，需要在指令里说明；云端服务无法访问你电脑上的 `127.0.0.1`。公网部署必须先确认入口支持客户端使用的流式协议。

## 完成后填写什么

| 客户端字段 | 本机部署示例 |
|---|---|
| Base URL | `http://127.0.0.1:7863/v1`，端口以实际安装结果为准 |
| API Key | 安装时生成的独立密钥 |
| 模型 | 从网关 `/v1/models` 返回结果中选择，并实际测试 |

不同客户端可能自行追加 `/v1`，应检查它的地址规则，避免最终变成 `/v1/v1/chat/completions`。本机地址仅在运行网关的机器上有效；NAS 使用 `http://<NAS 的局域网 IP>:7863/v1`，见 [NAS 部署说明](nas-deployment.md)。

默认使用桌面快捷方式手动启动，不注册开机自启。若希望助手修改当前客户端的供应商配置，需要明确同意，并且该客户端有可核实的 OpenAI 兼容接口配置入口。

## 公网与流式输出

Cloudflare **Quick Tunnel 不支持 SSE**，官方也未提供可用性 SLA；只能用于接受其限制的临时非流式测试。`/healthz` 能访问并不能证明流式对话能用。需要 SSE 时选择固定隧道或 HTTPS 反向代理，并实际测试增量输出。参见 [Cloudflare Quick Tunnels 官方限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)。

Skill 不包含任何 CodeBuddy 账号、真实 API Key 或已授权客户端配置。运行后生成的 `auths/`、`data/` 和实际 `config.json` 属于你的本地部署，不应加入发布包。
