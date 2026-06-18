# Platform Adapters / 云平台适配指南

> 本文档提供各主流 CI/CD 平台的完整流水线配置，**直接复制粘贴即可使用**。
>
> 所有配置遵循统一模式：检出代码 → 克隆审查工具 → 运行脚本 → 门禁判断 → 报告输出。

---

## 📋 文件复制指南（重要）

本仓库的 CI/CD 配置按平台分散存放，**不要直接修改原文件位置**：

| 你的平台 | 模板位置 | 复制到目标位置 |
|---------|---------|--------------|
| **GitHub** | `.github/workflows/code-review.yml` | **已生效，无需操作** |
| **阿里云效** | [`examples/aliyun-flow.yml`](../examples/aliyun-flow.yml) | 代码库根目录 → `.aliyun/pipelines.yml` |
| **腾讯云 CODING** | [`examples/tencent-coding.yml`](../examples/tencent-coding.yml) | 代码库根目录 → `ci.yml` |
| **Azure DevOps** | [`examples/azure-pipelines.yml`](../examples/azure-pipelines.yml) | 代码库根目录 → `azure-pipelines.yml` |
| **Jenkins** | [`examples/Jenkinsfile`](../examples/Jenkinsfile) | 代码库根目录 → `Jenkinsfile` |

**为什么这样设计？**
- `.github/workflows/` 是 GitHub 的**强制标准路径**，放在这里自动生效
- `examples/` 里的文件是**模板**，需要按各平台要求复制到指定位置才能生效

---

## Quick Reference / 速查表

| 平台 | 配置文件 | 触发方式 | PR 评论支持 |
|------|---------|---------|------------|
| **GitHub Actions** | `.github/workflows/code-review.yml` | PR / 手动 | ✅ `gh pr comment` |
| **阿里云效 Flow** | `.aliyun/pipelines.yml` | MR / 手动 | ✅ Webhook 回调 |
| **腾讯云 CODING** | `ci.yml` | MR / 手动 | ✅ API 评论 |
| **Azure DevOps** | `azure-pipelines.yml` | PR / 手动 | ✅ PR Thread API |
| **Jenkins** | `Jenkinsfile` | Webhook / 手动 | ✅ GitLab/GitHub API |
| **通用 Docker** | `Dockerfile` + `docker-entrypoint.sh` | 任意 | ❌ 仅日志（可扩展） |

---

## 0. 通用 Docker 镜像（推荐 / 云厂商无关）

如果你使用阿里云效、腾讯云 CODING、Jenkins 或其他任意支持 Docker 的 CI 平台，推荐先构建一个统一的审查镜像，各平台直接引用该镜像。这样无需每次流水线都克隆工具仓库，也避免网络波动导致失败。

### 0.1 构建并推送镜像

仓库根目录已提供 `Dockerfile` 和 `docker-entrypoint.sh`：

```bash
# 本地构建
docker build -t code-review-assistant:latest .

# 推送到你的镜像仓库（以阿里云 ACR 为例）
docker tag code-review-assistant:latest \
  registry.cn-hangzhou.aliyuncs.com/your-namespace/code-review-assistant:latest
docker push registry.cn-hangzhou.aliyuncs.com/your-namespace/code-review-assistant:latest
```

### 0.2 本地测试

```bash
# 直接运行（挂载当前目录）
docker run --rm -v $(pwd):/workspace code-review-assistant:latest

# 仅做密钥扫描
docker run --rm -v $(pwd):/workspace \
  -e SCAN_SECRET=true -e SCAN_DEPS=false -e SCAN_QUALITY=false \
  code-review-assistant:latest

# 使用 docker-compose（examples/docker-compose.yml）
docker compose -f examples/docker-compose.yml up --build
```

### 0.3 环境变量

| 变量 | 默认值 | 说明 |
| ------ | -------- | ------ |
| `SEVERITY` | `high` | 门禁阈值：`critical` / `high` / `medium` / `all` |
| `SCAN_SECRET` | `true` | 是否执行密钥扫描 |
| `SCAN_DEPS` | `true` | 是否执行依赖漏洞扫描 |
| `SCAN_QUALITY` | `true` | 是否执行代码质量检查 |
| `REPORT_DIR` | `/tmp/cra-reports` | 报告输出目录 |

### 0.4 各平台接入

| 平台 | Docker 模板 | 说明 |
| ------ | ------------ | ------ |
| 阿里云效 Flow | [`examples/aliyun-flow-docker.yml`](../examples/aliyun-flow-docker.yml) | 使用自定义镜像 |
| 腾讯云 CODING | [`examples/tencent-coding-docker.yml`](../examples/tencent-coding-docker.yml) | 使用自定义镜像 |
| Jenkins | [`examples/Jenkinsfile-docker`](../examples/Jenkinsfile-docker) | 使用 `agent { docker {...} }` |
| 本地测试 | [`examples/docker-compose.yml`](../examples/docker-compose.yml) | `docker compose up` |

---

## 1. GitHub Actions（已有，无需改动）

详见仓库根目录 [`.github/workflows/code-review.yml`](../.github/workflows/code-review.yml)。

```yaml
# 触发：PR 创建/更新/重新打开，或 Actions 页面手动触发
on:
  pull_request:
    types: [opened, synchronize, reopened]
  workflow_dispatch:
    inputs:
      severity: { default: 'all', type: choice, options: [critical, high, medium, all] }
      fix_mode: { default: false, type: boolean }
```

---

## 2. 阿里云效 Flow

将以下内容保存为代码库根目录的 `.aliyun/pipelines.yml`：

```yaml
version: 1.0
name: code-review-pipeline
trigger:
  push:
    branches:
      - master
      - main
      - 'feature/*'
  merge_request:
    action:
      - open
      - update
      - reopen

stages:
  build:
    name: "代码审查"
    jobs:
      code-review:
        runsOn: docker # 使用云效默认镜像
        steps:
          - checkout: self
            with:
              depth: 50

          - script:
              name: "安装依赖"
              script: |
                apt-get update && apt-get install -y git perl

          - script:
              name: "克隆审查工具"
              script: |
                git clone --depth 1 https://github.com/wzm111/code-review-assistant.git /tmp/cra

          - script:
              name: "Secret 扫描"
              script: |
                bash /tmp/cra/scripts/scan-secrets.sh . critical > /tmp/secrets.txt 2>&1 || true
                cat /tmp/secrets.txt

          - script:
              name: "依赖漏洞扫描"
              script: |
                bash /tmp/cra/scripts/scan-deps.sh . > /tmp/deps.txt 2>&1 || true
                cat /tmp/deps.txt

          - script:
              name: "代码质量检查"
              script: |
                bash /tmp/cra/scripts/code-smell.sh . > /tmp/smell.txt 2>&1 || true
                bash /tmp/cra/scripts/naming-convention.sh . > /tmp/naming.txt 2>&1 || true
                bash /tmp/cra/scripts/lint-check.sh . > /tmp/lint.txt 2>&1 || true
                cat /tmp/smell.txt /tmp/naming.txt /tmp/lint.txt

          - script:
              name: "质量门禁"
              script: |
                if ! bash /tmp/cra/scripts/severity-gate.sh . high; then
                  echo "::error::质量门禁未通过，请修复上述问题"
                  exit 1
                fi
```

### 阿里云效 + MR 评论（进阶）

如需将结果评论到阿里云 CodeUp MR，需添加 **Webhook 回调步骤**：

```yaml
          - script:
              name: "评论到 MR"
              script: |
                # 需要预先在阿里云效设置 CODEUP_TOKEN 环境变量
                REPORT="## 代码审查报告"
                REPORT+="$(cat /tmp/secrets.txt /tmp/smell.txt | head -50)"
                curl -s -X POST \
                  "https://devops.aliyun.com/api/v4/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/notes" \
                  -H "PRIVATE-TOKEN: ${CODEUP_TOKEN}" \
                  -d "body=${REPORT}" || true
```

---

## 3. 腾讯云 CODING CI

将以下内容保存为代码库根目录的 `ci.yml`：

```yaml
version: "2.0"

stages:
  - code-review

# 环境变量：在 CODING 项目设置中配置 SEVERITY（默认 high）
env:
  SEVERITY: "${{SEVERITY:-high}}"
  FIX_MODE: "${{FIX_MODE:-false}}"

code-review-job:
  stage: code-review
  image: ubuntu:22.04
  rules:
    - if: "$CI_PIPELINE_SOURCE == 'merge_request_event'"
    - if: "$CI_PIPELINE_SOURCE == 'web'"

  before_script:
    - apt-get update && apt-get install -y git curl perl
    - git clone --depth 1 https://github.com/wzm111/code-review-assistant.git /tmp/cra

  script:
    # Phase 1: 安全扫描
    - echo "=== Secret Scan ==="
    - bash /tmp/cra/scripts/scan-secrets.sh . critical > /tmp/secrets.txt 2>&1 || true
    - cat /tmp/secrets.txt

    # Phase 2: 依赖漏洞
    - echo "=== Dependency Scan ==="
    - bash /tmp/cra/scripts/scan-deps.sh . > /tmp/deps.txt 2>&1 || true
    - cat /tmp/deps.txt

    # Phase 3: 代码质量
    - echo "=== Code Quality ==="
    - bash /tmp/cra/scripts/code-smell.sh . > /tmp/smell.txt 2>&1 || true
    - bash /tmp/cra/scripts/naming-convention.sh . > /tmp/naming.txt 2>&1 || true
    - bash /tmp/cra/scripts/lint-check.sh . > /tmp/lint.txt 2>&1 || true
    - cat /tmp/smell.txt /tmp/naming.txt /tmp/lint.txt

    # Phase 4: 质量门禁
    - echo "=== Severity Gate ==="
    - |
      if ! bash /tmp/cra/scripts/severity-gate.sh . "$SEVERITY"; then
        echo "质量门禁未通过"
        GATE_FAILED=1
      fi

  after_script:
    # 生成合并报告
    - |
      echo "## CODING 代码审查报告" > /tmp/report.md
      echo "" >> /tmp/report.md
      for f in /tmp/secrets.txt /tmp/deps.txt /tmp/smell.txt /tmp/naming.txt /tmp/lint.txt; do
        if [ -s "$f" ]; then
          echo "<details><summary>$(basename $f)</summary>" >> /tmp/report.md
          echo '```' >> /tmp/report.md
          head -30 "$f" >> /tmp/report.md
          echo '```' >> /tmp/report.md
          echo "</details>" >> /tmp/report.md
          echo "" >> /tmp/report.md
        fi
      done
    - cat /tmp/report.md

  artifacts:
    paths:
      - /tmp/report.md
    expire_in: 7 days

  # 门禁失败则阻断流水线
  allow_failure: false
```

### CODING + MR 评论

在 `after_script` 中添加：

```yaml
  after_script:
    - |
      # 评论到 CODING MR（需配置 CODING_TOKEN）
      if [ -n "$CI_MERGE_REQUEST_IID" ]; then
        REPORT=$(cat /tmp/report.md | sed 's/"/\\"/g' | tr '\n' ' ')
        curl -s -X POST \
          "https://${CI_SERVER_HOST}/api/v3/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/notes" \
          -H "PRIVATE-TOKEN: ${CODING_TOKEN}" \
          -d "body=${REPORT}" || true
      fi
```

---

## 4. Azure DevOps Pipelines

将以下内容保存为代码库根目录的 `azure-pipelines.yml`：

```yaml
trigger:
  branches:
    include:
      - main
      - master
      - feature/*

pr:
  branches:
    include:
      - main
      - master

variables:
  severity: 'high'
  fixMode: false

pool:
  vmImage: 'ubuntu-latest'

steps:
  - checkout: self
    fetchDepth: 0

  - script: |
      sudo apt-get update && sudo apt-get install -y git perl
    displayName: 'Install dependencies'

  - script: |
      git clone --depth 1 https://github.com/wzm111/code-review-assistant.git $(Agent.TempDirectory)/cra
    displayName: 'Clone code-review-assistant'

  - script: |
      echo "=== Secret Scan ==="
      bash $(Agent.TempDirectory)/cra/scripts/scan-secrets.sh $(Build.SourcesDirectory) critical > $(Agent.TempDirectory)/secrets.txt 2>&1 || true
      cat $(Agent.TempDirectory)/secrets.txt
    displayName: 'Scan secrets'
    continueOnError: true

  - script: |
      echo "=== Dependency Scan ==="
      bash $(Agent.TempDirectory)/cra/scripts/scan-deps.sh $(Build.SourcesDirectory) > $(Agent.TempDirectory)/deps.txt 2>&1 || true
      cat $(Agent.TempDirectory)/deps.txt
    displayName: 'Scan dependencies'
    continueOnError: true

  - script: |
      echo "=== Code Quality ==="
      bash $(Agent.TempDirectory)/cra/scripts/code-smell.sh $(Build.SourcesDirectory) > $(Agent.TempDirectory)/smell.txt 2>&1 || true
      bash $(Agent.TempDirectory)/cra/scripts/naming-convention.sh $(Build.SourcesDirectory) > $(Agent.TempDirectory)/naming.txt 2>&1 || true
      bash $(Agent.TempDirectory)/cra/scripts/lint-check.sh $(Build.SourcesDirectory) > $(Agent.TempDirectory)/lint.txt 2>&1 || true
      cat $(Agent.TempDirectory)/smell.txt $(Agent.TempDirectory)/naming.txt $(Agent.TempDirectory)/lint.txt
    displayName: 'Code quality checks'
    continueOnError: true

  - script: |
      echo "=== Severity Gate ==="
      if ! bash $(Agent.TempDirectory)/cra/scripts/severity-gate.sh $(Build.SourcesDirectory) $(severity); then
        echo "##vso[task.logissue type=error]Quality gate failed"
        exit 1
      fi
    displayName: 'Severity gate'
    failOnStderr: false
```

### Azure + PR 评论

如需评论到 Azure PR，添加 **REST API 步骤**：

```yaml
  - task: PythonScript@0
    displayName: 'Post PR comment'
    inputs:
      scriptSource: 'inline'
      script: |
        import os, requests, urllib.parse
        
        org = os.environ['SYSTEM_TEAMFOUNDATIONCOLLECTIONURI'].split('/')[3]
        project = os.environ['SYSTEM_TEAMPROJECT']
        repo = os.environ['BUILD_REPOSITORY_NAME']
        pr_id = os.environ['SYSTEM_PULLREQUEST_PULLREQUESTID']
        token = os.environ['SYSTEM_ACCESSTOKEN']
        
        # 读取报告
        report = "## Azure DevOps 代码审查报告\n\n"
        for fname in ['secrets.txt', 'smell.txt', 'naming.txt', 'lint.txt']:
          path = os.path.join(os.environ['AGENT_TEMPDIRECTORY'], fname)
          if os.path.exists(path) and os.path.getsize(path) > 0:
            with open(path) as f:
              content = f.read()[:2000]
            report += f"<details><summary>{fname}</summary>\n\n```\n{content}\n```\n</details>\n\n"
        
        # 调用 Azure DevOps API
        url = f"https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}/pullRequests/{pr_id}/threads?api-version=7.0"
        headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}"}
        payload = {"comments": [{"content": report, "commentType": 1}], "status": 1}
        
        requests.post(url, headers=headers, json=payload)
```

---

## 5. Jenkins

将以下内容保存为代码库根目录的 `Jenkinsfile`：

```groovy
pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        SEVERITY = 'high'
        FIX_MODE = 'false'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Tools') {
            steps {
                sh '''
                    apt-get update -qq && apt-get install -y -qq git perl curl
                '''
            }
        }

        stage('Clone Review Assistant') {
            steps {
                sh '''
                    git clone --depth 1 https://github.com/wzm111/code-review-assistant.git /tmp/cra
                '''
            }
        }

        stage('Secret Scan') {
            steps {
                sh '''
                    bash /tmp/cra/scripts/scan-secrets.sh . critical > secrets.txt 2>&1 || true
                    cat secrets.txt
                '''
            }
        }

        stage('Dependency Scan') {
            steps {
                sh '''
                    bash /tmp/cra/scripts/scan-deps.sh . > deps.txt 2>&1 || true
                    cat deps.txt
                '''
            }
        }

        stage('Code Quality') {
            steps {
                sh '''
                    bash /tmp/cra/scripts/code-smell.sh . > smell.txt 2>&1 || true
                    bash /tmp/cra/scripts/naming-convention.sh . > naming.txt 2>&1 || true
                    bash /tmp/cra/scripts/lint-check.sh . > lint.txt 2>&1 || true
                    cat smell.txt naming.txt lint.txt
                '''
            }
        }

        stage('Severity Gate') {
            steps {
                sh '''
                    bash /tmp/cra/scripts/severity-gate.sh . "$SEVERITY"
                '''
            }
        }
    }

    post {
        always {
            // 归档报告
            archiveArtifacts artifacts: '*.txt', allowEmptyArchive: true

            // 生成汇总报告
            sh '''
                echo "## Jenkins 代码审查报告" > report.md
                echo "" >> report.md
                for f in secrets.txt deps.txt smell.txt naming.txt lint.txt; do
                    if [ -s "$f" ]; then
                        echo "### $f" >> report.md
                        echo '```' >> report.md
                        head -30 "$f" >> report.md
                        echo '```' >> report.md
                        echo "" >> report.md
                    fi
                done
                cat report.md
            '''
        }
        failure {
            echo '质量门禁未通过，请修复问题后重新构建'
        }
    }
}
```

---

## 6. 通用 Docker（任何平台）

如果你的平台支持 Docker（绝大多数都支持），最简方式是拉镜像直接跑：

```dockerfile
# Dockerfile.review
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y git perl curl

# 克隆审查工具（构建时）
RUN git clone --depth 1 https://github.com/wzm111/code-review-assistant.git /opt/cra

WORKDIR /workspace

# 默认执行审查
ENTRYPOINT ["bash", "/opt/cra/scripts/severity-gate.sh"]
CMD [".", "high"]
```

### 使用方式

```bash
# 构建
docker build -f Dockerfile.review -t code-review .

# 运行（挂载你的代码目录）
docker run -v $(pwd):/workspace code-review . high
```

### 各平台 Docker 步骤示例

**阿里云效**：
```yaml
  - step:
      name: "Docker 审查"
      image: your-registry/code-review:latest
      commands:
        - bash /opt/cra/scripts/severity-gate.sh . high
```

**腾讯云 CODING**：
```yaml
  code-review:
    image: your-registry/code-review:latest
    script:
      - bash /opt/cra/scripts/severity-gate.sh . high
```

---

## 环境变量速查

所有平台通用的环境变量配置：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SEVERITY` | `high` | 门禁阈值：`critical` / `high` / `medium` / `all` |
| `FIX_MODE` | `false` | 是否自动应用修复（仅在可信环境开启） |
| `SKIP_SECRET_SCAN` | `false` | 是否跳过密钥扫描 |
| `SKIP_DEP_SCAN` | `false` | 是否跳过依赖扫描 |

---

## 常见问题

### Q: 没有外网怎么克隆工具？

**方案 A**：把 `code-review-assistant` 作为 **git submodule** 嵌入你的仓库：

```bash
git submodule add https://github.com/wzm111/code-review-assistant.git .cra
```

然后流水线里改为：
```bash
bash .cra/scripts/scan-secrets.sh .
```

**方案 B**：把 `scripts/` 目录复制到你的仓库里，无需克隆。

### Q: 质量门禁失败会阻断合并吗？

是的。所有配置中 `severity-gate.sh` 返回非 0 时，流水线会失败，进而阻断 MR/PR 合并。

如需改为**警告模式**（不阻断），把门禁步骤改为：

```bash
bash scripts/severity-gate.sh . high || true
```

### Q: 大型仓库扫描太慢？

使用增量扫描（只扫描变更文件）：

```bash
# 只扫描上次提交以来的变更
CHANGED=$(git diff --name-only HEAD~1)
for f in $CHANGED; do
    bash scripts/scan-secrets.sh "$f" critical || true
done
```

---

*更多平台适配需求请提 Issue。*
