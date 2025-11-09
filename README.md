# hysteria_install

手搓 hysteria2

首先说明的是，尤其是白嫖 vps 的人，并不是白嫖一个 vps 就能搭建 hysteria2 的。需要测试 UDP 出站和入站是否正常，只有在正常的情况下，hytseria2 才能搭建成功，检测出站，入站可以问AI ，它会告诉你如何检测的，至于那个脚本，也是用chatGPT 写的，不一定行，所以写个手搓版的。

1. uname -m 查看 服务器架构

2. 下载hysteria2 x86_64 下载地址，其他架构，下载相应的版本就行了
	https://github.com/apernet/hysteria/releases/download/app%2Fv2.6.5/hysteria-linux-amd64

3. 获取本机公网IP	 三个查公网IP的地址，任选一个
	curl ipinfo.io / https://api.ipify.org / ifconfig.me
	
4. 创建自有证书
	服务器
	openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout your_key.key -out your_cert.crt -subj "/CN=VPS_IP" -addext "subjectAltName = IP:VPS_IP"
	
	生成客户端指纹，为客户端 pinSHA256 做准备，不想用可以去掉这个字段，保留 insecure: true
	openssl x509 -in your_cert.crt -noout -fingerprint -sha256 
	生成后的样子 sha256 Fingerprint=49:99:F4:F5:6F:F5:89:C1:FD:AF:83:33:1A:AD:20:7F:F0:29:B0:70:7B:19:0C:1C:5C:59:6A:DA:BA:26:A1:7E
   客户端配置字段的例子
		tls:
		  insecure: true	#禁用证书，然后启用 pinSHA256
		  pinSHA256: 49:99:F4:F5:6F:F5:89:C1:FD:AF:83:33:1A:AD:20:7F:F0:29:B0:70:7B:19:0C:1C:5C:59:6A:DA:BA:26:A1:7E

5. 服务端配置.yaml
```
	listen: ":port"	# 当只有端口没有 IP 地址时，服务器将监听所有可用的 IPv4 和 IPv6 地址。要仅监听 IPv4，可以使用 0.0.0.0:443。要仅监听 IPv6，可以使用 [::]:443。

	tls: # 每次 TLS 握手时都会读取证书。可以直接更新证书文件而无需重启服务端
	  cert: your_cert.crt # 这就是 openssl 生成的证书
	  key: your_key.key

	auth:
	  type: password
	  password: Se7RAuFZ8Lzg	# 用自己选的强密码进行替换。 客户端那边需要与服务器这边完全一致

	masquerade:	# 这里是伪装网站，假装自己是必应，更详细的解释看官方文档
	  type: proxy
	  proxy:
		url: "https://www.bing.com/"
		rewriteHost: true

	obfs:	# 将数据包混淆成没有特征的 UDP 包。此功能需要一个混淆密码，密码在客户端和服务端必须相同。
	  type: salamander
	  salamander:
		password: Se7RAuFZ8Lzg # 替换为你的混淆密码。密码一定要长，太短启动服务端时会报错


客户端配置.yaml 这里的配置是针对 hysteria2 客户端的，其他第三方的客户端配置，YouTube 有教学

	server: IP:Port # 连接服务器的IP:Port 
  
	auth: Se7RAuFZ8Lzg	# 连接服务器的密码
  
	tls:
	  insecure: true
	  pinSHA256: 49:99:F4:F5:6F:F5:89:C1:FD:AF:83:33:1A:AD:20:7F:F0:29:B0:70:7B:19:0C:1C:5C:59:6A:DA:BA:26:A1:7E
	  
	obfs: # 混淆
	  type: salamander 
	  salamander:
		password: Se7RAuFZ8Lzg
	socks5:	# 转发的端口，例如用浏览器代理这个地址端口就能上网
	  listen: 127.0.0.1:1080 
	http:
	  listen: 127.0.0.1:8080
    
目前只测试了这些字段，还有许多字段没有测试。

最后服务端运行 ./hysteria server -c 服务端配置.yaml
客户端运行 ./hysteria -c 客户端配置.yaml  客户端没有 server 的参数
	  
