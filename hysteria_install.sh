#!/usr/bin/env bash

# Hysteria2 用户态快速部署脚本（x86_64）
# 可修改端口、密码、SNI、ALPN

PORT=63010
PASSWORD='?-w]PVC2vT^JHm2'
SNI='www.bing.com'
ALPN='h3'
BIN_NAME='hysteria-linux-amd64'
CONFIG_FILE='server.yaml'
CERT_FILE='cert.pem'
KEY_FILE='key.pem'
DOWNLOAD_URL='https://github.com/apernet/hysteria/releases/download/app%2Fv2.6.5/hysteria-linux-amd64'

# 1️⃣ 下载 Hysteria2 二进制
echo "⏳ 下载 Hysteria2 二进制..."
wget -O $BIN_NAME "$DOWNLOAD_URL"
chmod +x $BIN_NAME
echo "✅ 下载完成"

# 2️⃣ 生成自签 TLS 证书（prime256v1）
echo "🔑 生成自签 TLS 证书..."
openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -days 3650 -keyout $KEY_FILE -out $CERT_FILE -subj "/CN=${SNI}"
echo "✅ 证书生成完成"

# 3️⃣ 写配置文件
cat > $CONFIG_FILE <<EOF
listen: ":${PORT}"
tls:
  cert: "$(pwd)/${CERT_FILE}"
  key: "$(pwd)/${KEY_FILE}"
  alpn:
    - "${ALPN}"
auth:
  type: "password"
  password: "${PASSWORD}"
bandwidth:
  up: "200mbps"
  down: "200mbps"
quic:
  max_idle_timeout: "10s"
  max_concurrent_streams: 4
  initial_stream_receive_window: 65536
  max_stream_receive_window: 131072
  initial_conn_receive_window: 131072
  max_conn_receive_window: 262144
EOF
echo "✅ 配置文件 $CONFIG_FILE 已生成"

# 4️⃣ 打印节点信息
IP=$(curl -s https://api.ipify.org || echo "YOUR_SERVER_IP")
echo "========================================================================="
echo "🎉 Hysteria2 部署完成"
echo "IP: $IP"
echo "端口: $PORT"
echo "密码: $PASSWORD"
echo "SNI: $SNI"
echo "ALPN: $ALPN"
echo "节点 URI:"
echo "hysteria2://${PASSWORD}@${IP}:${PORT}?sni=${SNI}&alpn=${ALPN}#Hy2-Node"
echo "========================================================================="

# 5️⃣ 启动 Hysteria2
echo "🚀 启动 Hysteria2..."
exec ./$BIN_NAME server -c $CONFIG_FILE
