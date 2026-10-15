# 升级、回退与分层验证

## 只升级 Hub

先取得当前服务状态、运行镜像摘要和版本、Compose 项目名与文件位置、实际挂载源、账号数量 / 区域以及 HTTPS 容器 ID 和启动时间。备份存放到用户的私有 NAS 目录，并限制权限，不打进发布包。

上游新正式版可直接安装，无需等 Skill 发版。先拉取目标镜像并确认版本 / 架构 / revision，对照 Release，不因为 `latest` 改变就自动升级。

暂停 Hub 后备份 `hub/accounts/`、`hub/usage/` 与 Compose / `.env`；记录 Caddyfile 和证书状态。修改的仅是 Hub 镜像引用：

```sh
# 使用原项目名称、目录与文件；示例省略了 -p / -f，请按现有实例补齐。
docker compose stop hub
# 现在制作私有数据快照，再修改 HUB_IMAGE 为已拉取并核验的摘要。
docker compose config --quiet
docker compose up -d --no-deps hub
```

不运行全项目 `down` / `up --force-recreate`，不顺带拉取或更新 Caddy。已有项目把镜像直接写在 Compose 中而非 `.env` 时，编辑原位置，不新建第二个项目。

等待健康状态后验证 accounts 数量、可用 Key、HTTPS 和实际模型请求。比较 HTTPS 容器 ID / 启动时间，确认未被重建。HTTP 429 是上游限流，要标明模型测试受限，不可归类为 TLS 故障。

失败时恢复旧镜像引用并只重建 Hub。若新版改变持久数据格式，使用停机时快照回退；如果新版已经刷新 OAuth Token，需先保全最新凭据并按目标版本格式转换，不能机械覆盖成旧 refreshToken。无法安全还原时停止进一步自动修改，报告保留的快照与状态。

## 验证顺序

1. **进程**：`docker compose ps`，确认两个服务正常；Hub `/health` JSON 的 `ok:true` 只代表服务健康，继续看账号就绪。
2. **账号**：`accounts` 与 `accounts_ready`、面板账号授权；模型目录不等同于登录成功。
3. **NAS 本机 HTTPS**：正确域名 / SNI 与受信证书，分别验证 `/`、`/panel/`、`/health`、`/healthz`；不以 `-k` 跳过证书验证作为最终结论。
4. **鉴权**：不带 Key 的 `/v1/models` 必须拒绝；带自己的有效 Key 能得到目录。Token 从私有配置读取到内存，不打印整份设置。
5. **真实对话**：按当前 API Key 的区域 / 模型范围选实际模型，先 `stream:false`；确认返回非空正文。推理模型需要足够输出预算；预算过小导致只有推理内容，不能直接断定服务坏了。
6. **SSE**：`stream:true`，核对 `text/event-stream`、增量事件与结束事件；记录首个增量时间和总耗时，避免只检查最终 HTTP 状态。
7. **公网**：在实际客户端网络中重复普通 HTTPS / SSE 检查，IPv4 和 IPv6 分别测试。NAS 内部 SNI 测试不能替代外网测试。

若可用 Key / 账号不足，明确注明未完成的测试，不替用户创建虚假测试结果。新安装真实对话会消耗账号额度，执行用户授权部署所需的少量测试即可，避免重复压测。

## 区分故障层

| 现象 | 优先排查 |
|---|---|
| NAS 直连 Hub 都失败 | Hub 进程、端口、挂载权限、镜像 / CPU 架构 |
| Hub 好，NAS 本机正确 SNI 的 HTTPS 失败 | Caddy 模块、Caddyfile、DNS-01、证书权限与时间 |
| NAS 本机 HTTPS 好，外网在 TLS 前 RST | 客户端出口、代理、防火墙或运营商；不先归因模型 |
| API HTTP 401 | API Key、区域 / 模型范围，不把面板登录密码当 API Key |
| HTTP 429 / queue full / too many requests | 上游额度或频率限制；等待冷却，不密集重试 |
| 模型目录有条目但对话无可用账号 | 登录状态、Key 的区域、账号授权、账号就绪 |
| 单一地址族失败 | 先确认测试端具备该地址族出口，再检查 A/AAAA 与入站 |

此架构仍由 NAS 中转对话流量。局域网客户端可通过私网 HTTPS 访问；公网客户端的模型回复占用 NAS 家宽上行。域名与 HTTPS 不会绕过 NAS。

## 交付清单

- 实际 Hub 版本与不可变镜像摘要、Caddy 版本和 DNS 插件。
- HTTPS Base URL、面板地址、模型名；API Key 仅在用户需要时展示。
- 账号数量及 ready 状态，不披露 UID、Token 或原始 settings.json。
- 普通 / 流式 / 外网验证的结果、时间、未完成原因。
- 私有持久目录、备份位置和回退步骤。
- 说明只更新了什么服务；不要承诺公网线路长期无故障。
