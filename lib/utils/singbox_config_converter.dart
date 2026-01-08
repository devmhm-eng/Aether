import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class SingboxConfigConverter {
  static String convertVlessUrlToSingbox(String vlessUrl) {
    try {
      final uri = Uri.parse(vlessUrl);
      if (uri.scheme != 'vless') {
        throw FormatException('Invalid scheme: ${uri.scheme}');
      }

      final uuid = uri.userInfo;
      final server = uri.host;
      final port = uri.port;
      final query = uri.queryParameters;
      final name = uri.fragment;

      // Extract transport settings
      final type = query['type'] ?? 'tcp';
      final security = query['security'] ?? 'none';
      final path = query['path'] ?? '/';
      final host = query['host'] ?? '';
      final sni = query['sni'] ?? '';
      final fp = query['fp'] ?? '';
      final pbk = query['pbk'] ?? '';
      final sid = query['sid'] ?? '';
      final alpnStr = query['alpn'] ?? '';
      final ech = query['ech'] ?? '';
      
      // allowInsecure: 1 = true, 0 = false. Default to true if not specified? 
      // User said "support tls", usually means verifying certs is better, but many v2ray configs use self-signed.
      // Let's respect the flag if present, default to true (insecure) to match previous behavior/compatibility.
      bool insecure = true;
      if (query.containsKey('allowInsecure')) {
          insecure = query['allowInsecure'] == '1';
      }

      // Build Outbound
      final outbound = {
        "type": "vless",
        "tag": "proxy",
        "server": server,
        "server_port": port,
        "uuid": uuid,
      };

      if (query.containsKey('flow') && query['flow']!.isNotEmpty) {
        outbound['flow'] = query['flow']!;
      }

      // Add Transport Details
      if (type == 'ws') {
        outbound['transport'] = {
          "type": "ws",
          "path": path,
          "headers": {
            "Host": host.isNotEmpty ? host : server
          }
        };
      } else if (type == 'grpc') {
         outbound['transport'] = {
          "type": "grpc",
          "service_name": query['serviceName'] ?? '',
        };
      }

      // Add TLS/Reality
      if (security == 'tls' || security == 'reality') {
        final tls = <String, dynamic>{
          "enabled": true,
          "server_name": sni.isNotEmpty ? sni : (host.isNotEmpty ? host : server),
          "insecure": insecure,
          "alpn": alpnStr.isNotEmpty ? alpnStr.split(',') : ["h2", "http/1.1"]
        };

        if (ech.isNotEmpty) {
           try {
             // Normalize Base64
             var cleanEchStr = ech.trim().replaceAll(RegExp(r'\s+'), '');
             cleanEchStr = cleanEchStr.replaceAll('-', '+').replaceAll('_', '/');
             while (cleanEchStr.length % 4 != 0) cleanEchStr += '=';
             
             print('DEBUG: Configuring VLESS ECH (Raw Base64): $cleanEchStr');
             
             tls['ech'] = {
                "enabled": true,
                "config": [cleanEchStr],  // Try raw base64 instead of PEM
                "pq_signature_schemes_enabled": false,
                "dynamic_record_sizing_disabled": false,
             };
           } catch (e) {
              print('ERROR: Failed to process ECH string: $e');
           }
        }
        
        if (security == 'reality') {
             tls['reality'] = {
                 "enabled": true,
                 "public_key": pbk,
                 "short_id": sid, // MUST be string, not array!
             };
             if (fp.isNotEmpty) {
                 tls['utls'] = {
                     "enabled": true,
                     "fingerprint": fp 
                 };
             }
        } else {
             // Standard TLS
             if (fp.isNotEmpty) {
                 tls['utls'] = {
                     "enabled": true,
                     "fingerprint": fp
                 };
             }
        }
        outbound['tls'] = tls;
      }
      
      return _wrapInFullConfig(outbound);
    } catch (e) {
      print("Error converting VLESS URL: $e");
      return "{}"; // Return empty or handle error
    }
  }

  static String convertVmessUrlToSingbox(String vmessUrl) {
    try {
      if (!vmessUrl.startsWith('vmess://')) {
        throw FormatException('Invalid scheme');
      }

      final base64Part = vmessUrl.substring(8);
      String decoded;
      try {
        decoded = utf8.decode(base64Decode(base64Part));
      } catch (e) {
        // Try with padding if failed
        decoded = utf8.decode(base64Decode(base64.normalize(base64Part)));
      }
      
      final Map<String, dynamic> config = jsonDecode(decoded);

      // Extract fields
      final server = config['add'] as String? ?? '';
      final port = int.tryParse(config['port'].toString()) ?? 443;
      final uuid = config['id'] as String? ?? '';
      final aid = int.tryParse(config['aid'].toString()) ?? 0;
      final scy = config['scy'] as String? ?? 'auto';
      final net = config['net'] as String? ?? 'tcp';
      final type = config['type'] as String? ?? 'none';
      final host = config['host'] as String? ?? '';
      final path = config['path'] as String? ?? '';
      final tls = config['tls'] as String? ?? 'none';
      final sni = config['sni'] as String? ?? '';
      final fp = config['fp'] as String? ?? '';
      final alpnStr = config['alpn'] as String? ?? '';

      // Build Outbound
      final outbound = {
        "type": "vmess",
        "tag": "proxy",
        "server": server,
        "server_port": port,
        "uuid": uuid,
        "security": scy,
        "alter_id": aid,
        "packet_encoding": "xudp",
      };

      // Transport Logic
      if (net == 'tcp') {
        if (type == 'http') {
           outbound['transport'] = {
            "type": "http",
            "host": host.split(','), // Support multiple hosts if comma separated
            "path": path,
          };
        }
      } else if (net == 'ws') {
        outbound['transport'] = {
          "type": "ws",
          "path": path,
          "headers": {
            "Host": host.isNotEmpty ? host : server
          }
        };
      } else if (net == 'grpc') {
        outbound['transport'] = {
          "type": "grpc",
          "service_name": path.isNotEmpty ? path : 'gun', // 'path' usually holds serviceName in vmess-grpc
        };
      }

      // TLS
      if (tls == 'tls') {
        final tlsConfig = <String, dynamic>{
          "enabled": true,
          "server_name": sni.isNotEmpty ? sni : (host.isNotEmpty ? host : server),
          "insecure": true, // VMess JSON doesn't usually have an 'allowInsecure' field in the standard share link, assume true.
          "alpn": alpnStr.isNotEmpty ? alpnStr.split(',') : ["h2", "http/1.1"]
        };
        
        if (fp.isNotEmpty) {
             tlsConfig['utls'] = {
                 "enabled": true,
                 "fingerprint": fp
             };
        }
        
        outbound['tls'] = tlsConfig;
      }
      
      return _wrapInFullConfig(outbound);
    } catch (e) {
      print("Error converting VMess URL: $e");
      return "{}";
    }
  }

  static String convertShadowsocksUrlToSingbox(String ssUrl) {
    try {
      if (!ssUrl.startsWith('ss://')) throw FormatException('Invalid scheme');

      final uri = Uri.parse(ssUrl);
      String userInfo = uri.userInfo;
      String server = uri.host;
      int port = uri.port;
      String method = '';
      String password = '';

      if (userInfo.isEmpty) {
        // Legacy format: ss://BASE64@host:port
        final authPart = ssUrl.substring(5, ssUrl.lastIndexOf('@'));
        final decoded = utf8.decode(base64Decode(authPart));
        final parts = decoded.split(':');
        method = parts[0];
        password = parts.sublist(1).join(':');
        
        final hostPart = ssUrl.substring(ssUrl.lastIndexOf('@') + 1);
        final valStart = hostPart.indexOf('#');
        final serverPortStr = valStart == -1 ? hostPart : hostPart.substring(0, valStart);
        
        // Simple host:port check
        final sp = serverPortStr.split(':');
        server = sp[0];
        port = int.parse(sp[1]);
      } else {
        // Standard user info: method:password (sometimes base64 encoded)
         if (userInfo.contains(':')) {
             // Plain text
             final parts = userInfo.split(':');
             method = parts[0];
             password = parts.sublist(1).join(':');
         } else {
             // Base64 encoded
             try {
                final decoded = utf8.decode(base64Decode(userInfo));
                final parts = decoded.split(':');
                method = parts[0];
                password = parts.sublist(1).join(':');
             } catch (_) {
                 // Fallback?
             }
         }
      }

      final outbound = {
        "type": "shadowsocks",
        "tag": "proxy",
        "server": server,
        "server_port": port,
        "method": method,
        "password": password,
        "plugin": uri.queryParameters['plugin'] ?? '',
        "plugin_opts": uri.queryParameters['plugin_opts'] ?? '',
      };

      return _wrapInFullConfig(outbound);
    } catch (e) {
      print("Error converting Shadowsocks URL: $e");
      return "{}";
    }
  }

  static String convertTrojanUrlToSingbox(String trojanUrl) {
    try {
      if (!trojanUrl.startsWith('trojan://')) throw FormatException('Invalid scheme');
      final uri = Uri.parse(trojanUrl);
      
      final password = uri.userInfo;
      final server = uri.host;
      final port = uri.port;
      final query = uri.queryParameters;

      final type = query['type'] ?? 'tcp';
      final security = query['security'] ?? 'tls';
      final sni = query['sni'] ?? query['peer'] ?? '';
      final alpnStr = query['alpn'] ?? '';
      final path = query['path'] ?? '/';
      final host = query['host'] ?? '';
      final serviceName = query['serviceName'] ?? '';
      final fp = query['fp'] ?? '';
      
      final outbound = {
        "type": "trojan",
        "tag": "proxy",
        "server": server,
        "server_port": port,
        "password": password,
      };

      // Transport
      if (type == 'ws') {
         outbound['transport'] = {
           "type": "ws",
           "path": path,
           "headers": {
             "Host": host.isNotEmpty ? host : server
           }
         };
      } else if (type == 'grpc') {
         outbound['transport'] = {
           "type": "grpc",
           "service_name": serviceName.isNotEmpty ? serviceName : path,
         };
      }

      // TLS
      if (security == 'tls' || security == 'xtls') {
        final tlsConfig = <String, dynamic>{
           "enabled": true,
           "server_name": sni.isNotEmpty ? sni : server,
           "insecure": query['allowInsecure'] == '1',
           "alpn": alpnStr.isNotEmpty ? alpnStr.split(',') : ["h2", "http/1.1"]
        };
        
        if (fp.isNotEmpty) {
           tlsConfig['utls'] = {
             "enabled": true,
             "fingerprint": fp
           };
        }
        outbound['tls'] = tlsConfig;
      }

      return _wrapInFullConfig(outbound);
    } catch (e) {
      print("Error converting Trojan URL: $e");
      return "{}";
    }
  }

  static String convertWireguardUrlToSingbox(String wgUrl) {
    try {
       // Format: wireguard://privateKey@server:port?publicKey=...&ip=...&mtu=...
       if (!wgUrl.startsWith('wireguard://')) throw FormatException('Invalid scheme');
       final uri = Uri.parse(wgUrl);
       
       final privateKey = uri.userInfo;
       final server = uri.host;
       final port = uri.port;
       final query = uri.queryParameters;
       
       final peerPublicKey = query['publicKey'] ?? '';
       final localAddress = query['ip'] ?? query['address'] ?? '10.0.0.1/32';
       final mtu = int.tryParse(query['mtu'] ?? '1280') ?? 1280;
       final reserved = query['reserved']; // comma separated ints
       
       final outbound = {
         "type": "wireguard",
         "tag": "proxy",
         "server": server,
         "server_port": port,
         "local_address": localAddress.split(','),
         "private_key": privateKey,
         "peer_public_key": peerPublicKey,
         "mtu": mtu,
       };
       
       if (reserved != null) {
          outbound['reserved'] = reserved.split(',').map((e) => int.tryParse(e) ?? 0).toList();
       }

       final udpOnly = query['udp_only'] == '1';

       return _wrapInFullConfig(outbound, udpOnly: udpOnly);
    } catch (e) {
      print("Error converting WireGuard URL: $e");
      return "{}";
    }
  }

  static String convertHysteria2UrlToSingbox(String hy2Url) {
    try {
       if (!hy2Url.startsWith('hy2://') && !hy2Url.startsWith('hysteria2://')) throw FormatException('Invalid scheme');
       final uri = Uri.parse(hy2Url);
       
       final password = uri.userInfo;
       final server = uri.host;
       final port = uri.port;
       final query = uri.queryParameters;
       
       final sni = query['sni'] ?? query['peer'] ?? '';
       final insecure = query['insecure'] == '1';
       final obfs = query['obfs'] ?? '';
       final obfsPassword = query['obfs-password'] ?? '';

       final outbound = {
         "type": "hysteria2",
         "tag": "proxy",
         "server": server,
         "server_port": port,
         "password": password,
         "tls": {
            "enabled": true,
            "server_name": sni.isNotEmpty ? sni : server,
            "insecure": insecure,
            "alpn": ["h3"]
         }
       };
       
       if (obfs.isNotEmpty && obfs != 'none') {
          outbound['obfs'] = {
             "type": obfs,
             "password": obfsPassword
          };
       }

       return _wrapInFullConfig(outbound);
    } catch (e) {
      print("Error converting Hysteria2 URL: $e");
      return "{}";
    }
  }

  static String _wrapInFullConfig(Map<String, dynamic> outbound, {bool udpOnly = false}) {
      final rules = <Map<String, dynamic>>[
            {"protocol": "dns", "outbound": "dns-out"},
      ];
      
      if (udpOnly) {
         // Prioritize UDP to proxy, TCP to direct (or block if preferred, but usually direct for split)
         rules.add({"network": "udp", "outbound": "proxy"});
         rules.add({"network": "tcp", "outbound": "direct"});
      }

      rules.add({"ip_is_private": true, "outbound": "direct"});
      
      bool isWindows = false;
      try {
        if (Platform.isWindows) isWindows = true;
      } catch (_) {}

      final Map<String, dynamic> inbound;
      
      if (isWindows) {
         // Windows Native Proxy (Mixed Inbound)
         inbound = {
            "type": "mixed",
            "tag": "mixed-in",
            "listen": "127.0.0.1",
            "listen_port": 10808,
            "set_system_proxy": true,
            "sniff": true
         };
      } else if (Platform.isAndroid) {
         // Android (TUN Inbound)
         inbound = {
            "type": "tun",
            "tag": "tun-in",
            "interface_name": "tun0",
            "inet4_address": "172.19.0.1/30",
            "auto_route": true,
            "stack": "system", // Use system stack for better compatibility
            "sniff": true,
            "sniff_override_destination": true
         };
      } else {
         // iOS/macOS (SOCKS Inbound for Tun2Socks)
         // We use Tun2Socks to capture traffic and forward it to this local SOCKS server.
         inbound = {
            "type": "socks",
            "tag": "socks-in",
            "listen": "127.0.0.1",
            "listen_port": 5000,
            "sniff": true,
            "sniff_override_destination": true
         };
      }

      final fullConfig = {
        "log": {
          "level": "info",
          "timestamp": true
        },
        "dns": {
          "servers": [
            {"tag": "google", "address": "8.8.8.8", "detour": "proxy"},
            {"tag": "local", "address": "1.1.1.1", "detour": "direct"}
          ],
          "rules": [
             {"outbound": "any", "server": "local"}
          ]
        },
        "inbounds": [inbound],
        "outbounds": [
          outbound,
          {"type": "direct", "tag": "direct"},
          {"type": "block", "tag": "block"},
          {"type": "dns", "tag": "dns-out"}
        ],
        "route": {
          "rules": rules,
           "auto_detect_interface": true
        }
      };
      
      // If mixed/windows, we might not need "auto_detect_interface" or "auto_route" logic in same way, 
      // but "auto_detect_interface" in route is usually fine.
      
      return jsonEncode(fullConfig);
  }
}
