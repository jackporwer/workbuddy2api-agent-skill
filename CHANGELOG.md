# 更新记录

## 2026.10.16 · NAS Hub + HTTPS

- 主 Skill 从桌面 / Panel 部署更新为极空间实际使用的 Hub + 独立 Caddy HTTPS 双服务架构。
- 参考 Hub v1.7.5、Caddy 2.11.7、DuckDNS 模块 v0.5.0；安装先查上游正式版本并固定镜像摘要。
- 提供 Compose、域名与端口样例、DNS Token 样例，以及可构建 DuckDNS 插件的 Caddy Dockerfile。
- 保留 `/panel/`、`/healthz` 兼容入口，保留账号、Key、用量、证书的持久目录。
- 增加已有实例接管、只升级 Hub、回退与分层排障；区分健康检查、账号 ready、普通对话、SSE 和公网验证。
- 旧 Panel 版归档至 `legacy/panel/`，保留历史 Release。
- 不附带桌面便携包、私人域名、NAS 用户路径、账号、DNS Token 或证书。

## 2026.10.14 · Panel

基于 linguo2625469/workbuddy2api-panel 的初版 Agent 部署 Skill，附带五平台 v1.13.0 备用包与 NAS 材料。
