#!/usr/bin/env sh

# --- 核心函数：从 GitHub API 获取最新版本号并去除前缀 ---
get_latest_version() {
    local repo="$1"
    local prefix="$2"
    # 使用 curl 获取 API 响应，并使用 grep/sed 提取 tag_name 字段的值
    version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | \
              grep -oP '"tag_name":\s*"\K[^"]+' | \
              sed "s/^${prefix}//")
    echo "$version"
}

# --- 1. XRAY 版本号自动检测与设置 ---
# 如果用户没有通过 env 传入 XRAY_VERSION，则自动获取最新版本
if [ -z "$XRAY_VERSION" ]; then
    echo "🔍 正在自动拉取 Xray-core 最新版本..."
    # Xray 版本号带有 'v' 前缀
    XRAY_VERSION=$(get_latest_version "XTLS/Xray-core" "v")
    if [ -z "$XRAY_VERSION" ]; then
        echo "⚠️ 自动获取 XRAY_VERSION 失败，将使用默认值 25.8.3。"
        XRAY_VERSION="25.8.3" # 失败时使用的备用版本
    else
        echo "✅ XRAY_VERSION: $XRAY_VERSION"
    fi
fi

# --- 2. HYSTERIA 2 版本号自动检测与设置 ---
# 如果用户没有通过 env 传入 HY2_VERSION，则自动获取最新版本
if [ -z "$HY2_VERSION" ]; then
    echo "🔍 正在自动拉取 Hysteria 2 最新版本..."
    # Hysteria 2 版本号带有 'app/v' 前缀
    HY2_VERSION=$(get_latest_version "apernet/hysteria" "app/v")
    if [ -z "$HY2_VERSION" ]; then
        echo "⚠️ 自动获取 HY2_VERSION 失败，将使用默认值 2.6.2。"
        HY2_VERSION="2.6.2" # 失败时使用的备用版本
    else
        echo "✅ HY2_VERSION: $HY2_VERSION"
    fi
fi


# --- 用户自定义变量（包含新增的版本变量） ---
# XRAY_VERSION="${XRAY_VERSION:-25.8.3}" # 已在上面逻辑中处理
# HY2_VERSION="${HY2_VERSION:-2.6.2}" # 已在上面逻辑中处理
DOMAIN="${DOMAIN:-node68.lunes.host}"
PORT="${PORT:-10008}"
UUID="${UUID:-2584b733-9095-4bec-a7d5-62b473540f7a}"
HY2_PASSWORD="${HY2_PASSWORD:-vevc.HY2.Password}"

curl -sSL -o app.js https://raw.githubusercontent.com/justlagom/edonyxorp/refs/heads/main/lunes-host/app.js
curl -sSL -o package.json https://raw.githubusercontent.com/justlagom/edonyxorp/refs/heads/main/lunes-host/package.json

# --- Xray 下载部分修改为使用变量 ---
mkdir -p /home/container/xy
cd /home/container/xy
# **使用 $XRAY_VERSION 变量**
curl -sSL -o Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$XRAY_VERSION/Xray-linux-64.zip
unzip Xray-linux-64.zip
rm Xray-linux-64.zip
mv xray xy
curl -sSL -o config.json https://raw.githubusercontent.com/justlagom/edonyxorp/refs/heads/main/lunes-host/xray-config.json
sed -i "s/10008/$PORT/g" config.json
sed -i "s/YOUR_UUID/$UUID/g" config.json
keyPair=$(./xy x25519)
privateKey=$(echo "$keyPair" | grep "Private key" | awk '{print $3}')
publicKey=$(echo "$keyPair" | grep "Public key" | awk '{print $3}')
sed -i "s/YOUR_PRIVATE_KEY/$privateKey/g" config.json
shortId=$(openssl rand -hex 4)
sed -i "s/YOUR_SHORT_ID/$shortId/g" config.json
vlessUrl="vless://$UUID@$DOMAIN:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.java.com&fp=chrome&pbk=$publicKey&sid=$shortId&spx=%2F&type=tcp&headerType=none#lunes-reality"
echo $vlessUrl > /home/container/node.txt

# --- Hysteria 2 下载部分修改为使用变量 ---
mkdir -p /home/container/h2
cd /home/container/h2
# **使用 $HY2_VERSION 变量**
curl -sSL -o h2 https://github.com/apernet/hysteria/releases/download/app%2Fv$HY2_VERSION/hysteria-linux-amd64
curl -sSL -o config.yaml https://raw.githubusercontent.com/justlagom/edonyxorp/refs/heads/main/lunes-host/hysteria-config.yaml
openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout key.pem -out cert.pem -subj "/CN=$DOMAIN"
chmod +x h2
sed -i "s/10008/$PORT/g" config.yaml
sed -i "s/HY2_PASSWORD/$HY2_PASSWORD/g" config.yaml
encodedHy2Pwd=$(node -e "console.log(encodeURIComponent(process.argv[1]))" "$HY2_PASSWORD")
hy2Url="hysteria2://$encodedHy2Pwd@$DOMAIN:$PORT?insecure=1#lunes-hy2"
echo $hy2Url >> /home/container/node.txt

echo "============================================================"
echo "🚀 VLESS Reality & HY2 Node Info"
echo "------------------------------------------------------------"
echo "$vlessUrl"
echo "$hy2Url"
echo "============================================================"
