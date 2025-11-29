#!/usr/bin/env sh

# --- 自动获取最新版本号 ---

# 函数：从 GitHub API 获取最新版本号并去除前缀（如 'v' 或 'app/v'）
get_latest_version() {
    local repo="$1"
    local prefix="$2"
    # 使用 curl 获取 API 响应，并使用 grep/sed 提取 tag_name 字段的值
    version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | \
              grep -oP '"tag_name":\s*"\K[^"]+' | \
              sed "s/^${prefix}//")
    echo "$version"
}

# 1. 自动获取 XRAY 最新版本 (XTLS/Xray-core)
if [ -z "$XRAY_VERSION" ]; then
    echo "🔍 正在自动拉取 Xray-core 最新版本..."
    # Xray 版本号带有 'v' 前缀
    XRAY_VERSION=$(get_latest_version "XTLS/Xray-core" "v")
    if [ -z "$XRAY_VERSION" ]; then
        echo "⚠️ 自动获取 XRAY_VERSION 失败，将使用默认值 25.9.11。"
        XRAY_VERSION="25.9.11"
    else
        echo "✅ XRAY_VERSION: $XRAY_VERSION"
    fi
fi

# 2. 自动获取 HYSTERIA 2 最新版本 (apernet/hysteria)
if [ -z "$HY2_VERSION" ]; then
    echo "🔍 正在自动拉取 Hysteria 2 最新版本..."
    # Hysteria 2 版本号带有 'app/v' 前缀
    HY2_VERSION=$(get_latest_version "apernet/hysteria" "app/v")
    if [ -z "$HY2_VERSION" ]; then
        echo "⚠️ 自动获取 HY2_VERSION 失败，将使用默认值 2.6.4。"
        HY2_VERSION="2.6.4"
    else
        echo "✅ HY2_VERSION: $HY2_VERSION"
    fi
fi

# 3. 自动获取 ARGO/cloudflared 最新版本 (cloudflare/cloudflared)
if [ -z "$ARGO_VERSION" ]; then
    echo "🔍 正在自动拉取 cloudflared 最新版本..."
    # cloudflared 版本号不带前缀
    ARGO_VERSION=$(get_latest_version "cloudflare/cloudflared" "")
    if [ -z "$ARGO_VERSION" ]; then
        echo "⚠️ 自动获取 ARGO_VERSION 失败，将使用默认值 2025.9.1。"
        ARGO_VERSION="2025.9.1"
    else
        echo "✅ ARGO_VERSION: $ARGO_VERSION"
    fi
fi

# --- 其余用户自定义变量保持不变 ---
DOMAIN="${DOMAIN:-node.waifly.com}"
PORT="${PORT:-10008}"
UUID="${UUID:-$(cat /proc/sys/kernel/random/uuid)}"
ARGO_DOMAIN="${ARGO_DOMAIN:-xxx.trycloudflare.com}"
ARGO_TOKEN="${ARGO_TOKEN:-}"
REMARKS_PREFIX="${REMARKS_PREFIX:-waifly}"

curl -sSL -o app.js https://raw.githubusercontent.com/vevc/one-node/refs/heads/main/waifly-host/app.js
curl -sSL -o package.json https://raw.githubusercontent.com/vevc/one-node/refs/heads/main/waifly-host/package.json

mkdir -p /home/container/cf
cd /home/container/cf
curl -sSL -o cf https://github.com/cloudflare/cloudflared/releases/download/$ARGO_VERSION/cloudflared-linux-amd64
chmod +x cf

mkdir -p /home/container/xy
cd /home/container/xy
rm -f *
curl -sSL -o Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$XRAY_VERSION/Xray-linux-64.zip
unzip Xray-linux-64.zip
rm Xray-linux-64.zip
mv xray xy
curl -sSL -o config.json https://raw.githubusercontent.com/vevc/one-node/refs/heads/main/waifly-host/xray-config.json
sed -i "s/10008/$PORT/g" config.json
sed -i "s/YOUR_UUID/$UUID/g" config.json
keyPair=$(./xy x25519)
privateKey=$(echo "$keyPair" | grep "PrivateKey" | awk '{print $2}')
publicKey=$(echo "$keyPair" | grep "Password" | awk '{print $2}')
sed -i "s/YOUR_PRIVATE_KEY/$privateKey/g" config.json
shortId=$(openssl rand -hex 4)
sed -i "s/YOUR_SHORT_ID/$shortId/g" config.json
wsUrl="vless://$UUID@$ARGO_DOMAIN:443?encryption=none&security=tls&fp=chrome&type=ws&path=%2F%3Fed%3D2560#$REMARKS_PREFIX-ws-argo"
echo $wsUrl > /home/container/node.txt
realityUrl="vless://$UUID@$DOMAIN:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=$publicKey&sid=$shortId&spx=%2F&type=tcp&headerType=none#$REMARKS_PREFIX-reality"
echo $realityUrl >> /home/container/node.txt

mkdir -p /home/container/h2
cd /home/container/h2
rm -f *
curl -sSL -o h2 https://github.com/apernet/hysteria/releases/download/app%2Fv$HY2_VERSION/hysteria-linux-amd64
curl -sSL -o config.yaml https://raw.githubusercontent.com/vevc/one-node/refs/heads/main/waifly-host/hysteria-config.yaml
openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout key.pem -out cert.pem -subj "/CN=$DOMAIN"
chmod +x h2
sed -i "s/10008/$PORT/g" config.yaml
sed -i "s/HY2_PASSWORD/$UUID/g" config.yaml
hy2Url="hysteria2://$UUID@$DOMAIN:$PORT?insecure=1#$REMARKS_PREFIX-hy2"
echo $hy2Url >> /home/container/node.txt

cd /home/container
sed -i "s/YOUR_DOMAIN/$DOMAIN/g" app.js
sed -i "s/10008/$PORT/g" app.js
sed -i "s/YOUR_UUID/$UUID/g" app.js
sed -i "s/YOUR_SHORT_ID/$shortId/g" app.js
sed -i "s/YOUR_PUBLIC_KEY/$publicKey/g" app.js
sed -i "s/YOUR_ARGO_DOMAIN/$ARGO_DOMAIN/g" app.js
sed -i 's/ARGO_TOKEN = ""/ARGO_TOKEN = "'$ARGO_TOKEN'"/g' app.js
sed -i "s/YOUR_REMARKS_PREFIX/$REMARKS_PREFIX/g" app.js

echo "✅ Installation completed, enjoy it ~"
