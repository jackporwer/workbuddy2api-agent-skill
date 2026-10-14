---
name: wb2api-setup
description: 先检查原项目最新正式 Release，在用户本机部署 WorkBuddy2API 网关；校验安装包、引导登录自己的账号并交付 Base URL、API Key 和模型名。适用于"帮我装 wb2api"、"部署 workbuddy 网关"、"配一个本地模型网关"，按需配置公网入口和客户端。
metadata:
  version: "2026.10.14"
  bundled-gateway-version: "1.13.0"
---

# wb2api 本地部署技能（无脚本版）

你（agent）负责把网关部署到用户本机。**用户是非技术人员**：你执行一切命令，
用户只做两件事——扫码登录、复制结果。

本技能基于原项目 https://github.com/linguo2625469/workbuddy2api-panel 整理。网关实现、面板与登录能力来自原项目；本技能是部署封装。

**安装前先检查原项目的最新正式 Release，有更新就优先直接部署新版。** `resources/` 内的五平台 v1.13.0 安装包是备用资源；同版本可以复用，版本检查或下载受限时可明确说明后使用备用包。不能把内嵌版本当成最新版。

---

## 铁律

1. **二进制只来自原项目 Release 或已内嵌的同源备用包**。执行前必须校验压缩包 SHA256，校验清单与安装包必须属于同一个 Release；校验失败中止，不能回退执行失败包。
2. **幂等**：每步先检测再执行，已完成则跳过。
3. **减少打断**：先复用用户已经说明的平台、使用场景和授权；只询问缺失且影响部署的信息。扫码由用户完成，配置当前 agent 需要用户同意。
4. **api_key 不写进日志**；仅在用户登录面板和最终交付时按需要展示，勿把整个配置文件打印到工具输出。
5. **不注册开机自启**（用户明确选择过：桌面快捷方式手动启动）。

---

## 已知坑（历史上真实踩过，务必绕开）

| # | 坑 | 正确做法 |
|---|---|---|
| 1 | **healthz 返回 503 不是故障**：200=有账号在池，503=服务活着但账号池空 | 安装阶段把 200 和 503 都视为成功；503 只需提示"扫码后消失" |
| 2 | 下载代理可能截断二进制 | 优先使用内嵌资源；升级从项目 Release 下载，对照对应版本的 checksums.txt 校验压缩包，再解压启动、检查健康状态。当前 v1.13.0 没有 `--version` 参数 |
| 3 | **PowerShell 5.1 不支持 `-SkipHttpErrorCheck`**（PS7 独有） | Win 上写 HTTP 探测时用 try/catch 从 `$_.Exception.Response.StatusCode` 取码 |
| 4 | **`Start-Process` 不允许 stdout/stderr 重定向到同一文件** | 分开两个文件，隧道日志读 stderr |
| 5 | **macOS Gatekeeper 拦截未公证二进制** | 解压后执行 `xattr -d com.apple.quarantine <二进制路径>`，否则"无效应用"报错 |
| 6 | **快速隧道 URL 首次出现可能要 40 秒以上** | 轮询日志至少 120 秒，别 30 秒就判定失败 |
| 7 | 把 `127.0.0.1` 链接发给另一台设备会打开那台设备自身 | 本机部署用本机浏览器打开面板；跨设备用部署机器的可达地址。项目面板使用设备授权轮询，凭据由网关落盘，不要求 NAS 运行浏览器 |

---

## 阶段 0：环境检测

按序检测并记录（后续步骤要用）：Windows 先确认 `$PSVersionTable` 和 `(Get-Process -Id $PID).Path`，复用当前已有 PowerShell 7，不另行安装或强制切换运行时。

1. **平台与架构**：Windows / macOS / Linux；`x64` 或 `arm64`
2. **先决定版本，再选资源包**：

   - 查询 `https://api.github.com/repos/linguo2625469/workbuddy2api-panel/releases/latest`，或阅读原项目 Releases 页面；只选正式发布，记录 `tag_name`、对应平台 asset 与同 Release 的 `checksums.txt` 下载地址。
   - 下表是备用 v1.13.0 文件映射。新版的实际文件名以 Release assets 为准，不拼接猜测不存在的文件名。
   - 目标版本与备用包一致时，可复用本地包；查询或下载不可用时，说明回退到 v1.13.0 及原因，不宣称使用了最新版。
   - 最新版缺少平台包 / 校验文件时，报告限制，可使用可校验的备用版；禁止混用版本的哈希。

   | 平台 | 架构 | 文件 |
   |---|---|---|
   | Windows | x64 | wb2api-panel-v1.13.0-windows-amd64.zip |
   | macOS | Apple Silicon (arm64) | wb2api-panel-v1.13.0-darwin-arm64.tar.gz |
   | macOS | Intel (x64) | wb2api-panel-v1.13.0-darwin-amd64.tar.gz |
   | Linux | x64 | wb2api-panel-v1.13.0-linux-amd64.tar.gz |
   | Linux | arm64 | wb2api-panel-v1.13.0-linux-arm64.tar.gz |

3. **端口**：先检查已有安装的配置与健康状态；复用已经运行的本服务。新安装探测 7863-7866，选可用端口，写入 `<安装目录>/PORT`，并在创建配置时同步到 `listen` 字段
4. **磁盘空间** ≥ 200MB

**安装目录约定**（不存在则创建）：
- Windows: `%LOCALAPPDATA%\wb2api`
- macOS: `~/Library/Application Support/wb2api`
- Linux: `~/.local/share/wb2api`

## 阶段 1：安装

目标状态（命令按平台自行组合）：

1. 下载所选原项目 Release 的平台包与该版本 checksums.txt，或选用本地备用包。**先校验压缩包 SHA256**：`Get-FileHash` / `shasum -a 256`，值必须等于该版本清单中的压缩包条目；本地备用包使用 `resources/checksums.txt`。清单不是解压后二进制的哈希。失败即中止，不解压、不执行
2. 解压校验通过的资源包到安装目录 → 得到 `wb2api`（或 `wb2api.exe`）、config.example.json
3. macOS 额外：`xattr -d com.apple.quarantine <bin>`（坑 #5）
4. `chmod +x <bin>`（posix）
5. 创建 `auths/`、`data/` 子目录
6. 生成 `config.json`：新版优先使用该 Release 包中的 `config.example.json`；内嵌 v1.13.0 可用 `templates/config.json`。检查该版本 README 的配置规则，
   把 `api_key` 字段设置为密码学安全随机生成的 `sk-wb2api-<40位随机>`（备用模板原值是 `__API_KEY__`）；把 `listen` 改为 `127.0.0.1:<所选端口>`（本机客户端或本机隧道使用）。其他字段沿用该版本样例；已有配置不覆盖
7. 首次启动：`<bin> -config <config.json>`，工作目录=安装目录，后台运行；Windows 后台服务使用 `Start-Process -WindowStyle Hidden`，stdout/stderr 分别重定向到不同文件
8. **验收**：`http://127.0.0.1:<端口>/healthz` 返回 **200 或 503** 都算成功
   （见坑 #1）；两者都返回 JSON 且 `service=="workbuddy2api"`
9. 将实际 `tag_name`、来源、平台、压缩包 SHA256 和安装时间写入 `<安装目录>/INSTALL_INFO.json`，不包含 API Key 或账号凭据。已有服务需要升级时按下方升级步骤执行，不能覆盖私有数据

完成后告知用户：「安装完成。接下来需要你扫码登录自己的 CodeBuddy 账号。」

## 阶段 2：添加账号（用户唯一参与步骤）—— 用户自助，agent 不碰浏览器

> 实测教训：不同环境里 agent 自动打开浏览器/驱动 OAuth 的成功率很低
> （无桌面、默认浏览器怪癖、权限拦截）。**本阶段一律由用户自己在浏览器
> 完成，你只负责给出地址和等待结果。**

目标：让 `auths/` 目录出现 `workbuddy-*.json`。

1. 若服务未运行先启动
2. **把两条信息原样输出给用户**（这是本阶段唯一的交付物）：

   ```
   请完成账号登录（两步）：

   1️⃣ 在这台电脑的浏览器打开（整行复制）：
      http://127.0.0.1:<端口>/panel/

   2️⃣ 打开后点「添加账号」，用微信扫码登录你自己的 CodeBuddy 账号。
      面板访问密钥（如被要求输入）：<api_key>

   此处使用 127.0.0.1，因此请在部署网关的这台电脑上打开面板。
   如果网关位于 NAS，请使用 NAS 的可达面板地址。
   ```

3. 你可以顺手 `open`/`xdg-open`/`Start-Process` 帮用户打开（失败**不重试、
   不影响流程**，用户自己开就行）
4. 轮询 `auths/`（每 3 秒，最长 10 分钟；给用户留足找手机扫码的时间）
5. 出现凭据文件 → 成功，向用户确认「登录成功 ✅」；超时 → 引导重试，
   连续失败转「故障排查 #2」

## 阶段 2.5：使用场景分叉（必须询问，决定后续走哪条线）

账号就绪后，向用户提问：

> 「你的 AI 工具（agent/客户端）是跑在这台电脑上的，
> 还是跑在云端（网页版 SaaS 平台）？
> ——这决定要不要给你配公网地址。」

| 用户回答 | 走哪条线 |
|---|---|
| **本机**（装在这台电脑上的 CLI/桌面 agent、Cherry Studio 等客户端） | **本地线**：**跳过阶段 3**，直接进阶段 4（用本地地址自检） |
| **云端 SaaS**（扣子、Dify 云版等网页平台） | **公网线**：继续阶段 3 → 阶段 4 |
| **两者都用** | 走公网线（公网地址本机也能用，一份信息通吃） |

**本地线交付时额外说明**（替代阶段 5 模板里的隧道提示）：
「你的服务仅本机可达，Base URL 用
`http://127.0.0.1:<端口>/v1`——比公网地址更快更稳。
以后如果要用云端 agent，再对我说"配公网地址"。」

后续用户说「配公网地址」→ 从阶段 3 开始执行（阶段 2.5 不再重复询问）。

## 阶段 3：暴露公网 HTTPS（仅公网线）

目标：得到一个公网可达的 HTTPS 地址，`https://<地址>/healthz` 返回 200 或 503。

**公网方案先按客户端是否需要流式输出选择**：

- 默认优先保持本机地址。确实需要云端 SaaS 接入时，再配置公网入口。
- 需要流式 SSE：使用能支持并经过实际 SSE 验证的固定隧道或 HTTPS 反向代理；可使用 Cloudflare 命名隧道，但需要用户已有账号和域名，不能当作免注册方案。
- Cloudflare Quick Tunnel 官方不支持 SSE，只能用于用户接受的临时非流式测试。不能因 `/healthz` 可达就把它交付给默认流式客户端。
- 参考：https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/

**临时非流式方案：Cloudflare 快速隧道**（零注册零配置）：

- 安装 cloudflared：Windows 下官方 exe 直下（**别走镜像**，坑 #2）；
  macOS `brew install cloudflared`；Linux 用官方 apt/yum 仓库或直下二进制
- 启动：`cloudflared tunnel --url http://127.0.0.1:<端口> --no-autoupdate`（后台）
- 从日志解析 `https://xxxx.trycloudflare.com`（**至少等 120 秒**，坑 #6）
- 公网实测 healthz → 200/503 都算通；530=隧道尚未注册好，等 5 秒重试

**升级方案：Tailscale Funnel**（固定地址，用户说"要固定地址"时才用）：
安装 Tailscale → 引导登录 → 查看当前 `tailscale funnel --help`。当前语法可直接 `tailscale funnel --bg http://127.0.0.1:<端口>`；检查 `tailscale funnel status`，以实际输出地址为准。不要混用旧版 `funnel 443 on` 语法。Funnel 前提与限制以 https://tailscale.com/docs/reference/tailscale-cli/funnel 为准，且交付前要验证实际 SSE 行为

把最终 URL 写入 `<安装目录>/PUBLIC_URL` 备用。

## 阶段 4：交付前自检清单（逐项验证，全部通过才能交付）

**两条线共用项**：

- [ ] 安装目录存在且含二进制、config.json、auths/、data/
- [ ] 压缩包 SHA256 校验通过（阶段 1 第 1 步的结果用户可见）
- [ ] 服务在监听（healthz 200 或 503）
- [ ] `auths/` 至少 1 个凭据文件，且 healthz 变为 200
- [ ] **真实对话测试**：`POST <BaseURL>/v1/chat/completions`，
      先查询 `/v1/models`，选择实际可用模型（可优先 `cn:auto`，但须确认存在），`stream=false`、max_tokens=16，能返回内容

**公网线追加项**（本地线不要求）：

- [ ] 公网 URL 实测可达（200/503）
- [ ] 客户端需要流式时，用 `stream=true` 实测 SSE 增量输出和正常结束；快速隧道不作为 SSE 方案

BaseURL 取值：本地线=`http://127.0.0.1:<端口>`；公网线=`PUBLIC_URL`。

## 阶段 5：交付

向用户展示（**按线取 BaseURL，公网线才显示隧道提示**）：

```
✅ 部署完成！三行接入信息（填进任意 OpenAI 兼容客户端）：

  Base URL : <按线：公网线=https://xxxx.trycloudflare.com/v1
                  本地线=http://127.0.0.1:<端口>/v1>
  API Key  : sk-wb2api-...
  模型名   : <从 /v1/models 获取且已实测成功的模型 ID>

[仅公网线显示] 💡 快速隧道地址在重启后会变 → 对本 agent 说"查网关地址"重取；
   想固定地址 → 说"升级固定地址"。
[本地线显示]  💡 此地址仅本机可用；以后要用云端 agent，说"配公网地址"。
```

**紧接着追问（本技能的收尾问题）**：

> 「要不要我现在把这个网关直接配置到当前 agent 里？我会先检查当前
> agent 是否支持自定义 OpenAI 兼容 API——支持就帮你配上，不支持会
> 告诉你原因和替代办法。」

**若用户同意，先自查再动手**：

1. 判断当前 agent 是否支持第三方 OpenAI 兼容 API：
   - 有自定义 provider/baseURL 配置（如 DSH、Cherry Studio 类）→ 支持
   - 没有可核实的自定义供应商配置入口 → 不写入臆造字段，说明当前环境限制，并交付三行信息供支持该接口的客户端使用
2. 支持则写入该 agent 的自定义模型配置（baseURL=上述地址、key、模型名），
   并实测一次对话确认生效

**桌面快捷方式**（默认创建，因未设开机自启）：

| 平台 | 位置 | 指向 |
|---|---|---|
| Windows | `%USERPROFILE%\Desktop\wb2api 启动.lnk` | `<bin> -config <配置路径>`，工作目录=安装目录；先确认该参数对应的服务未运行，避免重复启动 |
| macOS | `~/Desktop/wb2api.command` | 内容：`cd "<安装目录>" && ./wb2api -config config.json`，`chmod +x` |
| Linux | `~/Desktop/wb2api.desktop` | Exec=启动命令，Terminal=true |

快捷方式行为：启动服务（若已在跑则提示），不注册任何自启。
**同时告诉用户**：双击快捷方式即可启动网关，无需再叫 agent。

## 升级（用户说"更新版本"时）

1. 联网查原项目最新正式 Release（`https://github.com/linguo2625469/workbuddy2api-panel/releases`），比较目标版本与面板显示的版本，或读取 INSTALL_INFO.json；`config.json` 没有 `appVersion` 字段，不能以此判断。内嵌版本固定为 v1.13.0，不代表最新版本；不需要等待本 Skill 更新才部署原项目新版
2. 有新版 → 下载对应平台包与该版本 checksums.txt → **校验压缩包 SHA256，再解压到临时目录** → 保存旧二进制副本 → 停旧进程 → 仅替换二进制 → 重启，检查健康状态与实际对话；失败则还原旧二进制。auths/ data/ config.json 全保留，不使用不存在的 `--version` 参数
3. 校验任一环节失败 → 中止并报告，**绝不覆盖现有可运行版本**

---

## 用户后续指令映射

| 用户说 | 你做 |
|---|---|
| 查网关地址 | 本地线→输出 `http://127.0.0.1:<端口>/v1` 三行信息；公网线→读 `PUBLIC_URL`（失效则重起隧道）输出三行信息 |
| 配公网地址 | 本地线用户要上云端 agent → 执行阶段 3，完成后更新三行信息 |
| 模型不能用了 | 先 healthz：503→重跑添加账号；200→看故障排查 #4 |
| 升级固定地址 | 公网线：重做阶段 3 的 Tailscale 方案（本地线无此需求，先问是否要配公网） |
| 更新版本 | 走「升级」流程 |
| 卸载 | 停进程 → 删隧道配置（如有）→ 删桌面快捷方式 → 问"凭据文件是否一并删除？"（auths/ 含 CodeBuddy 登录凭据）→ 按答复删安装目录 |

## 故障排查

**#1 下载失败**（仅升级时会发生）：换网络/手机热点；哈希+大小校验必须过，过不了就中止。
**#2 扫码超时**：常见原因——用户没点「添加账号」就关了页面、扫了过期
二维码、或用手机打开了链接（坑 #7）。把阶段 2 的两条信息重新输出一遍
让用户重来（幂等，无副作用）；两次失败 → 请用户截图面板页面给你看。
**#3 隧道不通**：重启隧道 → 换手机热点区分网络拦截 → 切 Tailscale 档。
**#4 调用报错**：`401`=key 不对（重读 config.json）；`503`=池空（重扫码）；
`429 code=6004`=该模型当日额度尽（换模型，非故障）；TLS 失败=网络环境问题（同 #3）。
**#5 端口占用**：回到阶段 0 第 3 步顺延端口，重启服务，PUBLIC_URL 同步重做。

## 安全边界（向用户交代一次）

- api_key 与 CodeBuddy 凭据（auths/）都只存在本机
- 隧道地址=临时公网入口，靠 api_key 保护；三行信息别发群里
- 凭据文件=账号钥匙，别上传网盘/聊天工具
