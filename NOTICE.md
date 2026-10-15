# 来源与版本

本仓库当前主版本是 NAS Hub + 独立 Caddy HTTPS 的 Agent 部署封装。它根据实际极空间双服务架构整理，并去除所有私人运行参数与数据。

| 组成 | 来源 |
|---|---|
| 模型网关、面板、账号与协议实现 | https://github.com/ardeyouxipianyi/workbuddy2api-hub ，以原项目镜像运行，不修改其实现 |
| HTTPS 服务 | https://github.com/caddyserver/caddy ，参考 Caddy 2.11.7，采用其上游许可 |
| DNS-01 提供方 | https://github.com/caddy-dns/duckdns ，参考模块 v0.5.0 |
| Skill、部署与维护流程、Compose 和模板 | 本仓库根据极空间运行架构编写与整理 |
| 旧 Panel 版 | `legacy/panel/`，原来源及版权见其中 NOTICE.md 与根 LICENSE |

参考 Hub v1.7.5 摘要固定在 env.example 中，仅用于可追溯部署。安装 / 升级时检查上游最新正式版本，确认对应 GHCR 版本、revision 与平台后再固定摘要。不得把 Release ZIP 哈希用作容器镜像摘要。

模板使用 Dockerfile 构建带 DuckDNS 插件的 Caddy，因此与参考 NAS 的“标准运行时 + 挂载自定义二进制”在打包方式上不同；保留了独立 HTTPS、持久目录、代理兼容路径和 DNS-01 流程。新构建二进制需要在目标平台验证。

发行包不包含第三方网关二进制、账号、Key、DNS Token、证书、日志、私人域名或实际 NAS 路径。Caddy 及其依赖的许可由其项目 / 构建镜像保留；本仓库的部署材料按根 LICENSE 提供，保留历史来源版权。
