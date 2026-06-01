# DevOps / 运维 审查专项规则

## 1. Dockerfile
- [ ] 是否用多阶段构建（减小镜像体积）？
- [ ] 基础镜像是否指定具体版本（非 `latest`）？
- [ ] 是否以非 root 用户运行（`USER` 指令）？
- [ ] 敏感数据是否用 BuildKit secrets（非 `ARG`/`ENV`）？
- [ ] `COPY` 是否精确（避免复制整个上下文）？
- [ ] `apt-get` 是否在同一 RUN 中 `update && install && rm`？

## 2. Kubernetes
- [ ] 资源限制是否设置（`resources.limits` / `requests`）？
- [ ] 健康检查是否配置（`livenessProbe` / `readinessProbe`）？
- [ ] Secret 是否用 K8s Secret / 外部 Vault（非明文）？
- [ ] Pod 是否有反亲和性/分布策略？
- [ ] 是否避免 `hostNetwork` / `privileged: true`？
- [ ] HPA 是否配置（自动扩缩容）？

## 3. CI/CD
- [ ] 流水线是否有缓存（依赖、构建产物）？
- [ ] 测试失败是否阻断发布？
- [ ] 是否有制品扫描（SAST/DAST/依赖漏洞）？
- [ ] 部署是否有回滚策略？
- [ ] 环境变量是否区分 dev/staging/prod？

## 4. Terraform / IaC
- [ ] State 文件是否远程存储（S3 + DynamoDB 锁定）？
- [ ] 资源命名是否有环境前缀？
- [ ] 是否避免硬编码凭证（用变量/数据源）？
- [ ] `terraform plan` 是否强制 review 后 apply？

## 5. 监控
- [ ] 应用是否有指标暴露（Prometheus /metrics）？
- [ ] 日志是否结构化（JSON）并分级？
- [ ] 告警是否配置（Error rate / Latency / CPU / Memory）？
- [ ] 分布式追踪是否接入（OpenTelemetry / Jaeger）？
