#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Hysteria2 用户态部署脚本（x86_64，端口63010，ALPN=h3）
# 适合免费 VPS，无 root 权限
# 注意：LF 换行，UTF-8 无 BOM，直接可在 GitHub 上编辑和上传

set -e

# ---------- 配置参数 ----------
HYSTERIA_VERSION="v2.6.5"
SERVER_PORT=63010
AUTH_PASSWORD='?-w]PVC2vT^JHm2'
SNI="www.bing.com"
ALPN="h3"
CERT_FILE="cert.pem"
KEY_FILE="key.pem"
BANDWIDTH_UP="200mbps"
BANDWIDTH_DOWN="200mbps"

BIN_NAME="hysteria-linux-x86_64"
BIN_PATH="./${BIN_NAME}"

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Hysteria2 用户态部署脚本（端口: ${SERVER_PORT}, ALPN: ${ALPN}）"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# ---------- 下载二进制 ----------
if [ ! -f "$BIN_PATH" ]; then
    echo "⏳ 下载 Hysteria2 二进制..."
    curl -L --retry 3 --connect-timeout 30 -o "$BIN_PATH" \
        "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/${BIN_NAME}"
    chmod +x "$BIN_PATH"
    echo "✅ 下载完成"
else
    echo "✅ 二进制已存在，跳过下载"
fi

# ---------- 生成自签证书 ----------
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "🔑 生成自签 TLS 证书..."
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -days 3650 -keyout "$KEY_FILE" -out "$CERT_FILE" -subj "/CN=${SNI}"
    echo "✅ 证书生成完成"
else
    echo "✅ 发现现有证书，使用已有 cert/key"
fi

# ---------- 写入配置文件 ----------
cat > server.yaml <<EOF
listen: ":${SERVER_PORT}"
tls:
  cert: "$(pwd)/${CERT_FILE}"
  key: "$(pwd)/${KEY_FILE}"
  alpn:
    - "${ALPN}"
auth:
  type: "password"
  password: "${AUTH_PASSWORD}"
bandwidth:
  up: "${BANDWIDTH_UP}"
  down: "${BANDWIDTH_DOWN}"
quic:
  max_idle_timeout: "10s"
  max_concurrent_streams: 4
  initial_stream_receive_window: 65536
  max_stream_receive_window: 131072
  initial_conn_receive_window: 131072
  max_conn_receive_window: 262144
EOF

echo "✅ 配置文件 server.yaml 已生成"

# ---------- 获取服务器 IP ----------
SERVER_IP=$(curl -s --max-time 10 https://api.ipify.org || echo "YOUR_SERVER_IP")
echo "🌐 服务器 IP: $SERVER_IP"

# ---------- 打印连接信息 ----------
echo "=========================================================================="
echo "🎉 Hysteria2 部署成功！"
echo "端口: $SERVER_PORT"
echo "密码: $AUTH_PASSWORD"
echo "SNI: $SNI"
echo "ALPN: $ALPN"
echo ""
echo "📱 节点 URI（客户端可直接使用）:"
echo "hysteria2://${AUTH_PASSWORD}@${SERVER_IP}:${SERVER_PORT}?sni=${SNI}&alpn=${ALPN}#Hy2-Node"
echo ""
echo "📄 客户端配置示例:"
echo "server: ${SERVER_IP}:${SERVER_PORT}"
echo "auth: ${AUTH_PASSWORD}"
echo "tls:"
echo "  sni: ${SNI}"
echo "  alpn: [\"${ALPN}\"]"
echo "  insecure: true"
echo "socks5:"
echo "  listen: 127.0.0.1:1080"
echo "http:"
echo "  listen: 127.0.0.1:8080"
echo "=========================================================================="

# ---------- 启动 Hysteria2 服务器 ----------
echo "🚀 启动 Hysteria2..."
exec "$BIN_PATH" server -c server.yaml
