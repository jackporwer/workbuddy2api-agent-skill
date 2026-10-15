# 来源与附带文件说明

本项目是 [linguo2625469/workbuddy2api-panel](https://github.com/linguo2625469/workbuddy2api-panel) 的 Agent Skill 封装与部署材料整理。原项目本身基于 Sliverkiss/workbuddy2api 演进，原始作者与增强分支作者的版权声明保留在 LICENSE 中。

| 本仓库文件 | 来源与改动 |
|---|---|
| `skills/wb2api-setup/SKILL.md` | 将原项目安装、登录、验证和维护步骤整理为 Agent 可执行流程；安装时先检查原项目正式 Release |
| `skills/wb2api-setup/resources/*` | 原项目 v1.13.0 Release 的五平台安装压缩包与 checksums.txt，二进制未修改 |
| `skills/wb2api-setup/templates/config.json` | 基于原项目配置整理的 v1.13.0 备用模板，API Key 为占位符 |
| `deploy/nas/config.example.json` | 基于原项目配置样例，真实部署前应设置自己的密钥；部署新版时优先使用新版包中的配置样例 |
| `deploy/nas/docker-compose.yml` | 使用原项目 GHCR 镜像，改为配置目录挂载，并显式指定配置路径 |
| `deploy/nas/Dockerfile` | 将原项目 Linux Release 二进制置入容器，保留非 root 运行、CA 证书与时区支持 |
| `deploy/nas/build.ps1` | 从原项目 Release 获取对应 Linux 安装包与同版本校验文件，校验后准备 / 构建 / 导出镜像；不包含网关实现 |
| `guides/*` | 根据原项目代码、部署方式与相关官方文档编写的使用说明 |

安装新版本不会要求本仓库预先内嵌该版本。Agent 或构建脚本直接解析原项目的 Release，选择对应平台文件并校验。同版本的本地备用包可复用；备用包的 SHA256 不能用于校验其他版本。

所有生成的账号凭据、运行配置、API Key、日志与浏览器数据均属于用户的私有部署，不应随本项目发布。
