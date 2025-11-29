## Usage

```bash
curl -s https://raw.githubusercontent.com/justlagom/edonyxorp/refs/heads/main/waifly-host/install.sh |
env DOMAIN=项目域名 PORT=27796 UUID='自定义uuid' ARGO_DOMAIN='固定隧道域名' ARGO_TOKEN='隧道tocken' bash
```
（无需设定内核版本，默认拉取最新正式版，如有特定版本内核需求请参考 XRAY_VERSION=25.9.11 HY2_VERSION=2.6.4 ARGO_VERSION=2025.9.1 ）
