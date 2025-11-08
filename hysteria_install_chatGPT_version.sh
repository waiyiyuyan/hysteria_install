#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Hysteria2 用户模式守护脚本（无 root / 免费 VPS / 超低内存）
# 功能: 自动下载、生成证书、后台启动、守护进程自动重启

set -euo pipefail

# =================== 用户可配置参数 ===================
# 用户可以修改这些参数，根据需要填写
# -------------------------------------------------------
PASSWORD="?-w]PVC2vT^JHm2"       # 🔹 用户密码（客户端连接时用），建议修改为复杂密码
SNI="www.bing.com"               # 🔹 TLS SNI，用于混淆，可按需修改
ALPN="h3"                        # 🔹 ALPN协议，可按需修改，通常不用改
DEFAULT_PORT=22222                # 🔹 默认端口，用户可在执行脚本时传入新端口
HYSTERIA_VER="v2.6.5"            # 🔹 hysteria2 二进制版本，如需升级可修改
# ========================================================

# ---------------- 使用命令行端口参数覆盖默认端口 ----------------
PORT="${1:-$DEFAULT_PORT}"
if [ "$PORT" -le 1024 ]; then
  echo "⚠️ 请使用非特权端口 (>1024)"
  exit 1
fi

# ---------------- 辅助函数 ----------------
has() { command -v "$1" >/dev/null 2>&1; }

# ---------------- 架构检测 ----------------
arch_detect() {
  local m=$(uname -m | tr '[:upper:]' '[:lower:]')
  case "$m" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7*|armv6*) echo "arm" ;;
    *) echo "" ;;
  esac
}
ARCH=$(arch_detect)
if [ -z "$ARCH" ]; then
  echo "❌ 无法识别架构 $(uname -m)，请手动上传 hysteria 二进制文件。"
  exit 1
fi

BIN_NAME="hysteria-linux-${ARCH}"
BIN_PATH="./${BIN_NAME}"
CERT_FILE="cert.pem"
KEY_FILE="key.pem"
LOG_FILE="hysteria.log"
PID_FILE="hysteria.pid"

# ---------------- 下载 hysteria2 ----------------
download_hysteria() {
  if [ -x "$BIN_PATH" ]; then return; fi
  echo "⏳ 下载 hysteria2 (${ARCH}) ..."
  local urls=(
    "https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VER}/${BIN_NAME}"
    "https://github.com/apernet/hysteria/releases/latest/download/${BIN_NAME}"
    "https://ghproxy.com/https://github.com/apernet/hysteria/releases/latest/download/${BIN_NAME}"
  )
  for url in "${urls[@]}"; do
    echo "➡️ 尝试 $url"
    if has curl; then curl -fL --retry 2 --connect-timeout 15 -o "$BIN_PATH" "$url" && break || true; fi
    if has wget; then wget -q -O "$BIN_PATH" "$url" && break || true; fi
  done
  if [ ! -s "$BIN_PATH" ]; then
    echo "❌ 下载失败，请手动上传 ${BIN_NAME}"
    exit 1
  fi
  chmod +x "$BIN_PATH"
  echo "✅ 下载完成"
}

# ---------------- 生成证书 ----------------
generate_cert() {
  if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then return; fi
  if ! has openssl; then
    echo "⚠️ 无 openssl，无法生成证书，请手动上传 cert.pem/key.pem"
    exit 1
  fi
  echo "🔑 生成自签证书..."
  openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -days 3650 -keyout "$KEY_FILE" -out "$CERT_FILE" -subj "/CN=${SNI}" >/dev/null 2>&1
  echo "✅ 自签证书生成完成"
}

# ---------------- 写配置 ----------------
write_config() {
cat > server.yaml <<EOF
listen: ":${PORT}"
tls:
  cert: "$(pwd)/${CERT_FILE}"
  key: "$(pwd)/${KEY_FILE}"
  alpn:
    - "${ALPN}"
auth:
  type: password
  password: "${PASSWORD}"
EOF
  echo "✅ server.yaml 配置完成"
}

# ---------------- 后台启动函数 ----------------
start_hysteria() {
  nohup "$BIN_PATH" server -c server.yaml >> "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
}

# ---------------- 守护循环 ----------------
daemon_loop() {
  echo "🚀 启动守护进程..."
  while true; do
    if [ ! -f "$PID_FILE" ] || ! kill -0 $(cat "$PID_FILE") 2>/dev/null; then
      echo "$(date '+%F %T') - 启动 hysteria2 服务..."
      start_hysteria
      sleep 1
      if kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "✅ hysteria2 已启动，PID: $(cat "$PID_FILE")"
      else
        echo "❌ 启动失败，请查看 $LOG_FILE"
      fi
    fi
    sleep 5
  done
}

# ---------------- 获取公网 IP ----------------
get_ip() {
  if has curl; then curl -s https://api.ipify.org || echo "YOUR_IP"
  elif has wget; then wget -qO- https://api.ipify.org || echo "YOUR_IP"
  else echo "YOUR_IP"; fi
}

# ---------------- 主流程 ----------------
main() {
  download_hysteria
  generate_cert
  write_config
  echo "🎉 hysteria2 配置完成"

  IP=$(get_ip)
  echo "📡 IP: $IP 端口: $PORT"
  echo "🔑 密码: $PASSWORD"
  echo "🌐 SNI: $SNI  ALPN: $ALPN"
  echo "客户端 URI: hysteria2://${PASSWORD}@${IP}:${PORT}?sni=${SNI}&alpn=${ALPN}#Hy2"
  echo "日志: tail -f $LOG_FILE"
  echo "停止服务: kill \$(cat $PID_FILE)"
  echo "-----------------------------------------"

  daemon_loop
}

main "$@"
