# 安全深度审查专项规则

## 1. OWASP Top 10 (2025)
- [id: security:owasp-a01-broken-access-control] [ ] **A01 - 失效访问控制**：接口是否鉴权？IDOR（不安全的直接对象引用）？
- [id: security:owasp-a02-crypto-failure] [ ] **A02 - 加密失败**：密码是否 bcrypt/Argon2（非 MD5/SHA1）？传输是否 TLS 1.3？
- [id: security:owasp-a03-injection] [ ] **A03 - 注入**：SQL / NoSQL / LDAP / OS Command 注入？
- [id: security:owasp-a04-insecure-design] [ ] **A04 - 不安全设计**：业务逻辑漏洞（优惠券重复使用、负金额）？
- [id: security:owasp-a05-config-misconfig] [ ] **A05 - 安全配置错误**：默认密码、调试模式、CORS 过宽？
- [id: security:owasp-a06-cve] [ ] **A06 - 漏洞组件**：依赖是否有 CVE（Snyk / OWASP DC）？
- [id: security:owasp-a07-auth-failure] [ ] **A07 - 身份识别失败**：JWT 是否过期/刷新？会话固定攻击？
- [id: security:owasp-a08-data-integrity] [ ] **A08 - 数据完整性**：供应链攻击（签名验证）？反序列化过滤？
- [id: security:owasp-a09-logging] [ ] **A09 - 日志监控**：安全事件是否记录？是否有异常检测？
- [id: security:owasp-a10-ssrf] [ ] **A10 - SSRF**：服务器端请求是否限制目标地址？

## 2. 认证与授权
- [id: security:password-policy] [ ] 密码策略：长度、复杂度、历史密码？
- [id: security:mfa-required] [ ] MFA 是否强制（敏感操作）？
- [id: security:oauth-oidc-implementation] [ ] OAuth 2.0 / OIDC 是否正确实现（state 参数、PKCE）？
- [id: security:rbac-abac-minimal] [ ] RBAC / ABAC 是否最小权限原则？
- [id: security:jwt-secret-strength] [ ] JWT Secret 是否强随机（256-bit+）？
- [id: security:token-short-expiry] [ ] Token 是否短过期 + 刷新机制？

## 3. 输入验证
- [id: security:server-side-validation] [ ] 所有输入是否在服务端校验（客户端不可信）？
- [id: security:file-upload-validation] [ ] 文件上传：类型、大小、MIME、病毒扫描？
- [id: security:path-traversal-filter] [ ] 路径遍历：`../` 过滤、chroot？
- [id: security:xss-output-encoding] [ ] XSS：输出编码（CSP、HttpOnly Cookie）？
- [id: security:csrf-protection] [ ] CSRF：Token / SameSite Cookie / Referer 校验？

## 4. 加密与密钥
- [id: security:modern-algorithm] [ ] 算法是否现代（AES-256-GCM / ChaCha20-Poly1305）？
- [id: security:iv-nonce-unique] [ ] IV / Nonce 是否唯一（非重复使用）？
- [id: security:kms-hsm-key] [ ] 密钥是否 KMS / HSM 管理（非硬编码）？
- [id: security:forward-secrecy] [ ] 是否前向保密（Forward Secrecy）？

## 5. 审计与合规
- [id: security:audit-log] [ ] 敏感操作是否审计日志（谁、何时、做了什么）？
- [id: security:log-tamper-proof] [ ] 日志是否防篡改（WORM 存储）？
- [id: security:pii-minimize] [ ] PII 数据是否最小化收集（GDPR / 个保法）？
- [id: security:data-classification] [ ] 数据是否分类分级（公开/内部/机密/绝密）？
- [id: security:penetration-test] [ ] 是否定期渗透测试 / 代码审计？
