# NAS 部署与网络说明

这些 NAS 材料基于 [原项目 workbuddy2api-panel](https://github.com/linguo2625469/workbuddy2api-panel) 整理，实际网关来自原项目镜像或 Release 二进制。网关适合运行在支持 Docker 的 NAS 上。管理面板、账号凭据和模型转发都运行在 NAS 中；你的客户端通过 NAS 调用 CodeBuddy 上游。NAS 不是只管理账号的控制台。

## 准备目录与配置

选择一个 NAS 上实际存在、你有写权限的 Docker 项目目录。复制本仓库的 `deploy/nas/docker-compose.yml` 和 `deploy/nas/config.example.json`，组织成：

```text
wb2api/
├── docker-compose.yml
├── conf/
│   └── config.json       # 从 config.example.json 复制后编辑
├── auths/                # 登录后自动保存账号凭据
└── data/                 # 自动保存状态和统计
```

如果通过 SSH 操作，在选定目录执行：

```bash
mkdir -p conf auths data
# 将下载好的 config.example.json 复制到 conf/config.json
cp config.example.json conf/config.json
```

编辑 `conf/config.json`：把 `api_key` 设置为自己生成的长随机密钥，并确认 `listen` 为 `:7863`、`auth_dir` 为 `./auths`、`state_file` 为 `./data/state.json`。不要复制别人正在使用的配置与凭据。

Compose 示例使用原项目 GHCR `latest` 镜像。部署前查看原项目 Release 和实际镜像标签，确认版本与 CPU 架构；正式使用时可以固定已存在的镜像标签。使用新版时，优先从该版 Release 包获取 config.example.json，再设置自己的 API Key。仓库中的配置样例与 v1.13.0 对齐，不能假设永远覆盖新版全部选项。

需要离线导入 NAS 时，可以在 Windows Docker 环境运行本仓库的 `deploy/nas/build.ps1`。脚本默认查询原项目最新正式 Release，下载并校验对应 Linux 平台包，构建后导出镜像 tar 和 SHA256。也可用 `-Version v1.13.0` 固定版本，或用 `-Architecture arm64` 选择 ARM NAS。`-PrepareOnly` 只准备并校验文件，不要求 Docker。导入 tar 后将 Compose 的 `image` 改为脚本输出的镜像名称。

配置挂载使用整个 `conf/` 目录。程序保存配置时会创建临时文件并原子替换，单独挂载一个 `config.json` 文件可能阻碍该过程。示例同时覆盖镜像入口与参数，确保服务真正读取 `/app/conf/config.json`。

## 启动与登录

在 NAS 的 Docker / Compose 管理界面导入项目并启动，或在项目目录执行：

```bash
docker compose up -d
docker compose logs --tail=50
```

同一局域网内的电脑浏览器打开：

```text
管理面板：http://<NAS 的局域网 IP>:7863/panel/
健康检查：http://<NAS 的局域网 IP>:7863/healthz
API 地址：http://<NAS 的局域网 IP>:7863/v1
```

在面板中输入你设置的 API Key，点击「添加账号」，按页面提示完成设备授权。**NAS 本身不需要图形界面或浏览器。** 当前面板向上游轮询授权状态，再由 NAS 保存凭据并加入账号池。不要把 NAS 的地址写成客户端的 `127.0.0.1`。

如果此前已经在自己的电脑上登录，也可以停止电脑端网关后，将自己的 `auths/` 文件复制到 NAS 再启动。首次使用优先通过 NAS 面板登录，无需先搭一个 Windows 实例。

`/healthz` 返回 503 可能表示无健康账号，不能仅凭状态码断定进程启动失败；结合 JSON 中的 `service`、`healthy`、`total` 和日志判断。账号正常后查询 `/v1/models`，选择实际可用模型，并分别测试普通与流式对话。

## 目录权限

容器默认以 UID/GID 10001 运行。若日志出现写入凭据、状态或配置时的 `permission denied`，让挂载目录可由容器用户写入，或使用 NAS 上有权限的用户 UID/GID。

例如，在可使用 SSH 的 Linux 环境中，可用当前用户运行：

```bash
PUID=$(id -u) PGID=$(id -g) docker compose up -d --force-recreate
```

也可在项目目录的本地 `.env` 中设置实际 `PUID` 与 `PGID`。示例不要求容器以 root 运行。

## 流量是否经过 NAS

```text
发送请求：客户端 → NAS 网关 → CodeBuddy / WorkBuddy 上游
接收回复：客户端 ← NAS 网关 ← CodeBuddy / WorkBuddy 上游
```

所有通过该网关发出的模型请求和回复都经过 NAS。模型上游流式返回时，NAS 持续读取并转发 SSE；非流式模式则由 NAS 聚合后返回。依据原项目中的 `internal/server/handler.go`、`internal/upstream/client.go`、`internal/upstream/sse.go`；本仓库不包含这些网关实现文件。

| 使用方式 | 家宽上传占用 | 家宽下载占用 |
|---|---|---|
| 客户端和 NAS 同一局域网，直接访问局域网地址 | NAS 发给上游的请求 | NAS 从上游接收的回复 |
| 客户端在外网，远程访问家中的 NAS | 发给上游的请求，以及转发给客户端的回复 | 从客户端接收的请求，以及从上游接收的回复 |

在家里直接连接 NAS 时，回复由 NAS 经局域网交给电脑，不再占用一次家宽上行。外网使用时，家宽上行还承担回复转发。

用一个假设估算：请求 2 MB，上游回复与下游回复均约 1 MB，忽略协议开销与重试。在家调用约占用家宽上传 2 MB、下载 1 MB；外网调用约占用家宽上传 3 MB、下载 3 MB。此处是路径计算，不是实测。

请求中包含历史对话、代码或内嵌图片时，上传时间可能比逐字输出更明显。NAS 向上游发送 5 MB 请求，在 10 Mbps 可用上行下理论约需 4 秒，在 30 Mbps 下约需 1.33 秒；还需加上其他链路、延迟和上游处理时间。SSE 的实际字节数包括 JSON 和事件封装，不能仅按最终文本大小计算。

个人低并发、主要在家使用，可优先尝试 NAS；经常在外网使用或并发发送大上下文请求时，应以实际可用上行、连接稳定性和首个输出等待时间决定是否将网关放到其他机器。

## 外网入口与流式配置

仅自己的设备需要远程访问时，可使用 NAS 支持的 VPN 或私有组网。云端 SaaS 需要公网可达入口，使用 HTTPS 反向代理或固定隧道，并保留网关 API Key 鉴权。

如果使用 Nginx，核对 SSE 缓冲与超时，例如在现有 HTTPS 站点中配置：

```nginx
location / {
    proxy_pass http://<NAS 的局域网 IP>:7863;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_buffering off;
    proxy_read_timeout 600s;
}
```

这是代理片段，不包含证书配置；应按实际域名、NAS 地址和现有站点补齐。参考 [Nginx 官方 proxy_buffering 文档](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffering)。不要直接将 HTTP 7863 端口作为公网入口。

Cloudflare Quick Tunnel 官方不支持 SSE，不能用于默认流式客户端；详见 [官方限制](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)。健康检查能访问后，仍须实际验证 SSE 持续输出与正常结束。

## 维护

```bash
docker compose ps
docker compose logs --tail=100
docker compose restart
docker compose down
# 检查版本与备份后更新使用 registry 镜像的部署
docker compose pull
docker compose up -d
```

备份自己的 `conf/`、`auths/` 与 `data/`，并限制备份访问。发布到 GitHub 的只应是示例配置和部署说明，不包含你的实际 API Key、账号凭据或运行日志。
