# 部署与接管

## 已验证架构与模板区别

参考部署于 2026-10-15 升级到 Hub v1.7.5；2026-10-16 只读检查 `/health` 仍返回 `ok:true`，账号就绪。Hub 镜像摘要为：

```text
ghcr.io/ardeyouxipianyi/workbuddy2api-hub@sha256:27c6f3f9eebc83d1ad50281f244fe7399a8974c523609a5b87db760e76752dc1
```

HTTPS 为独立 Caddy 2.11.7，已验证包含 DuckDNS v0.5.0 模块。参考 NAS 把自定义 `caddy` 二进制挂载进标准运行时；可分享模板改为用 Dockerfile 在镜像内构建同版本与插件。架构、持久目录和路径兼容规则一致，但模板不携带私人二进制、证书或运行配置。新构建的镜像与 NAS 原镜像不是同一摘要，不能声称已经验证新构建产物。

现有实例以 `docker inspect` 的真实挂载、端口、入口为准。不能因模板用 `hub` 服务名，就把用户已有 Caddyfile 中可用的容器名盲目替换；不能覆盖原 `https` 服务的 entrypoint 和可执行文件挂载。

## 新建实例

先确认 NAS 的持久路径。极空间显示路径可能对应 `/tmp/zfsv3/...`，不要把别人的账号目录或临时编号硬编码进去。

将 `assets/nas/` 的内容完整复制到目标目录，然后：

```sh
cp env.example .env
cp https/duckdns.env.example https/duckdns.env
mkdir -p hub/accounts hub/usage https/data https/config
```

填写 `.env` 中自己的域名与镜像，`https/duckdns.env` 中自己的 DNS Token。核对实际 UID/GID 后，让四个运行目录可写，并保护文件：

```sh
# 10001:10001 是模板默认值；如果改了 PUID/PGID，下面也应改为实际值。
chown -R 10001:10001 hub/accounts hub/usage https/data https/config
chmod 700 hub/accounts hub/usage https/data https/config
chmod 600 .env https/duckdns.env
docker compose config --quiet
docker compose build https
docker compose run --rm --no-deps https list-modules
docker compose run --rm --no-deps https validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker compose up -d
docker compose ps
```

先构建时拉取 Caddy 构建镜像与模块，需要联网。没有 Docker socket 挂载；面板内的 Docker 自动更新功能不作为此架构的更新方式。

首次启动若面板仍使用默认密码，先通过本机 SSH 转发、私网或临时入站限制完成初始化和改密，再开放公网。`--lan` 模式下确认 API 已启用 Key 鉴权。首次生成 Key 可能出现在 Hub 原生日志，读取日志时应掩码，不能把原始日志直接发布。

## DDNS、证书和公网

- 极空间 DDNS 负责 A/AAAA 更新；Caddy DuckDNS 插件负责 DNS-01 TXT 验证，两者职责不同。
- DNS-01 可在不开放 80/443 入站时签发证书，外部客户端仍必须能连接你映射的 HTTPS TCP 端口。IPv4 常需路由端口转发；CGNAT 下 DDNS 不会自动建立入站路径。
- 公布 AAAA 前要从真正有 IPv6 出口的外网验证入站。不能用一台没有 IPv6 出口的电脑测失败后认定 NAS IPv6 有问题；不要为此关闭整台路由器的 IPv6。
- TLS 必须使用正确域名 / SNI 验证。直接访问 IPv6 字面地址而域名证书不匹配，不构成域名 HTTPS 故障证据。
- 保留 `https/data` 里的生产证书与 ACME 账号。证书换域名或新申请不是 Hub 更新的必要步骤。

## 账号登录与旧版迁移

管理面板为 `https://<域名>:<端口>/panel/`；也可先用 SSH 转发访问本地诊断端口。按该 Hub 版本的设备授权流程添加自有账号，不把其他机器的 `127.0.0.1` 链接当成 NAS 地址。

从旧 Panel 迁移时，备份旧配置和凭据，只把它们在私网只读挂载给 Hub 的导入预览。使用目标版 `AccountPool.preview_import_rows` / `import_rows` 或面板导入功能，核对国内 / 国际区域映射。API Key 和面板密码是独立设置；保留旧 API Key 不意味着应把它永久复用为面板密码。

不得让两个实例同时刷新同一份凭据。停旧实例后导入，验证账号授权、普通对话和 HTTPS。回退前应核对是否需要同步刷新后的凭据。清理旧容器、镜像和备份另需明确清理任务，不能当作安装或升级的默认步骤。

## 官方来源

- Hub：https://github.com/ardeyouxipianyi/workbuddy2api-hub
- Hub Releases：https://github.com/ardeyouxipianyi/workbuddy2api-hub/releases
- DuckDNS 插件：https://github.com/caddy-dns/duckdns
- Caddy 自定义构建：https://caddyserver.com/docs/build
- Docker Compose：https://docs.docker.com/compose/
