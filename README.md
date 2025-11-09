# hysteria_install — 手搓 hysteria2

> 说明：本文档为手工搭建 Hysteria2 的简明指南，适合没有 root 权限、使用免费 VPS 的场景。**注意**：并不是所有免费 VPS 都能成功搭建 Hysteria2，必须先检测 UDP 出/入站是否正常。

---

## 目录

1. [准备工作](#准备工作)
2. [下载 Hysteria 二进制](#下载-hysteria-二进制)
3. [获取公网 IP](#获取公网-ip)
4. [生成自签 TLS 证书](#生成自签-tls-证书)
5. [服务端配置示例（server.yaml）](#服务端配置示例serveryaml)
6. [客户端配置示例（client.yaml）](#客户端配置示例clientyaml)
7. [启动命令](#启动命令)
8. [常见问题与注意事项](#常见问题与注意事项)

---

## 准备工作

1. 登录 VPS，检查架构：

```bash
uname -m
```

根据返回结果选择对应的 Hysteria 二进制（x86_64、arm64 等）。

> 提示：若返回 `x86_64` 或 `amd64`，可使用下面的示例二进制下载地址。

## 下载 Hysteria 二进制

示例（x86_64）：

```bash
curl -L -o hysteria-linux-amd64 https://github.com/apernet/hysteria/releases/download/app%2Fv2.6.5/hysteria-linux-amd64
chmod +x hysteria-linux-amd64
```

如果是其它架构，请到官方 releases 页面下载对应文件。

## 获取公网 IP

三选一：

```bash
curl ipinfo.io
curl https://api.ipify.org
curl ifconfig.me
```

把得到的公网 IP 记下来，用在证书 CN/subjectAltName 与客户端连接地址上。

## 生成自签 TLS 证书（示例）

在服务器上生成自签证书（将 `VPS_IP` 替换为你的公网 IP）：

```bash
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
  -keyout your_key.key -out your_cert.crt \
  -subj "/CN=VPS_IP" \
  -addext "subjectAltName = IP:VPS_IP"
```

为了做客户端的 `pinSHA256`（证书指纹），可运行：

```bash
openssl x509 -in your_cert.crt -noout -fingerprint -sha256
```

输出示例：

```
SHA256 Fingerprint=49:99:F4:...:A1:7E
```

> 说明：如果你不想启用证书校验，可以在 `server`/`client` 配置中使用 `insecure: true`。

## 服务端配置示例（server.yaml）

将下面示例保存为 `server.yaml`，并根据实际替换 `:port`、证书路径、密码与伪装网站等字段。

```yaml
listen: ":55000" # 非 root 用户请使用 >1024 端口

tls:
  cert: "/home/container/your_cert.crt" # openssl 生成的证书路径
  key: "/home/container/your_key.key"

auth:
  type: password
  password: Se7RAuFZ8Lzg # 请替换为你自己的强密码

masquerade:
  type: proxy
  proxy:
    url: "https://www.bing.com/"
    rewriteHost: true

obfs:
  type: salamander
  salamander:
    password: Se7RAuFZ8Lzg # 混淆密码（客户端与服务端必须相同）
```

**说明与建议**：

* `listen`：当只有端口没有 IP 地址时，服务器将监听所有可用的 IPv4/IPv6 地址。若要仅监听 IPv4 可写 `0.0.0.0:55000`。
* `tls`：每次 TLS 握手会读取证书，更新证书无需重启服务端（取决于实现）。
* `masquerade`：用于流量伪装为正常 HTTPS 请求（示例伪装为 bing）。
* `obfs`：用于将流量混淆为无特征的 UDP 包，`salamander` 需要提供足够长度的密码，否则启动会报错。

## 客户端配置示例（client.yaml）

将下面示例保存为客户端配置（或对应第三方客户端的字段），并替换 `IP:Port`、密码与 `pinSHA256`：

```yaml
server: VPS_IP:55000

auth: Se7RAuFZ8Lzg

tls:
  insecure: true
  pinSHA256: 49:99:F4:F5:6F:F5:89:C1:FD:AF:83:33:1A:AD:20:7F:F0:29:B0:70:7B:19:0C:1C:5C:59:6A:DA:BA:26:A1:7E

obfs:
  type: salamander
  salamander:
    password: Se7RAuFZ8Lzg

socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:8080
```

**说明**：

* `insecure: true` 与 `pinSHA256` 可以同时出现：`insecure: true` 会跳过通用 CA 验证，而 `pinSHA256` 对服务器证书做指纹校验，提高安全性。
* 如果不想做指纹校验，可删除 `pinSHA256` 字段并保留 `insecure: true`（不推荐用于生产环境）。

## 启动命令

在服务器端运行：

```bash
./hysteria-linux-amd64 server -c server.yaml
```

在客户端运行：

```bash
./hysteria-linux-amd64 -c client.yaml
```

> 注意：客户端启动命令没有 `server` 参数。

## 常见问题与注意事项

* **为什么有些 VPS 搭建不成功？**

  * Hysteria 依赖 UDP，若 VPS 的出/入站 UDP 被限制或 NAT/防火墙不支持，会导致无法连接。建议先测试 UDP（使用 `iperf3` 或简单的 UDP 打点测试）。

* **如何检测 UDP 支持性？**

  * 可以用 `iperf3` 做 UDP 测试，或者用简单的客户端/服务端 UDP 脚本测试可达性。

* **证书与 pinSHA256 的用途？**

  * `pinSHA256` 是对服务器证书的指纹校验，可以在跳过 CA 验证的情况下（`insecure`）仍保持对指定证书的校验。

* **配置中出现 YAML 解析错误怎么办？**

  * 常见原因：缩进不一致（不要混用 Tab 和空格）、字符串未用引号包裹导致特殊字符解析、注释位置错误等。使用 2 或 4 个空格统一缩进。

* **端口被占用 / 查看与杀死进程**

```bash
# 查找占用 55000 端口的进程（示例）
ss -ltnp | grep 55000
# 或
lsof -i :55000

# 杀死进程
kill <PID>
# 强制杀死
kill -9 <PID>
```

---

如需：

* 我可以把此 Markdown 导出为 `.md` 文件并提供下载；
* 或者我可以把配置根据你的 VPS 与端口直接替换成可用示例（无需你重复信息）。

如果需要我直接替换某些字段（例如 `VPS_IP`、`port`、证书路径或自定义密码），直接告诉我要替换为什么即可。
