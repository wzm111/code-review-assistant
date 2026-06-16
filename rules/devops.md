# DevOps / 运维 审查专项规则

## 1. Dockerfile
- [id: devops:multi-stage-build] [ ] 是否用多阶段构建（减小镜像体积）？
- [id: devops:base-image-pin-version] [ ] 基础镜像是否指定具体版本（非 `latest`）？
- [id: devops:non-root-user] [ ] 是否以非 root 用户运行（`USER` 指令）？
- [id: devops:buildkit-secrets] [ ] 敏感数据是否用 BuildKit secrets（非 `ARG`/`ENV`）？
- [id: devops:copy-precision] [ ] `COPY` 是否精确（避免复制整个上下文）？
- [id: devops:apt-get-cleanup] [ ] `apt-get` 是否在同一 RUN 中 `update && install && rm`？

## 2. Kubernetes
- [id: devops:resource-limits] [ ] 资源限制是否设置（`resources.limits` / `requests`）？
- [id: devops:health-probes] [ ] 健康检查是否配置（`livenessProbe` / `readinessProbe`）？
- [id: devops:secret-management] [ ] Secret 是否用 K8s Secret / 外部 Vault（非明文）？
- [id: devops:pod-anti-affinity] [ ] Pod 是否有反亲和性/分布策略？
- [id: devops:avoid-hostnetwork-privileged] [ ] 是否避免 `hostNetwork` / `privileged: true`？
- [id: devops:hpa-configured] [ ] HPA 是否配置（自动扩缩容）？

## 3. CI/CD
- [id: devops:pipeline-cache] [ ] 流水线是否有缓存（依赖、构建产物）？
- [id: devops:test-blocks-deploy] [ ] 测试失败是否阻断发布？
- [id: devops:artifact-scanning] [ ] 是否有制品扫描（SAST/DAST/依赖漏洞）？
- [id: devops:rollback-strategy] [ ] 部署是否有回滚策略？
- [id: devops:env-separation] [ ] 环境变量是否区分 dev/staging/prod？

## 4. Terraform / IaC
- [id: devops:remote-state-lock] [ ] State 文件是否远程存储（S3 + DynamoDB 锁定）？
- [id: devops:env-prefix-naming] [ ] 资源命名是否有环境前缀？
- [id: devops:no-hardcoded-creds] [ ] 是否避免硬编码凭证（用变量/数据源）？
- [id: devops:plan-before-apply] [ ] `terraform plan` 是否强制 review 后 apply？

## 5. 监控
- [id: devops:prometheus-metrics] [ ] 应用是否有指标暴露（Prometheus /metrics）？
- [id: devops:structured-logging] [ ] 日志是否结构化（JSON）并分级？
- [id: devops:alerting-configured] [ ] 告警是否配置（Error rate / Latency / CPU / Memory）？
- [id: devops:distributed-tracing] [ ] 分布式追踪是否接入（OpenTelemetry / Jaeger）？
