# Code Review Assistant / 代码审查助手
# 云厂商无关的通用审查镜像
#
# 构建:
#   docker build -t code-review-assistant:latest .
#
# 运行（本地目录挂载为 /workspace）:
#   docker run --rm -v $(pwd):/workspace code-review-assistant:latest
#
# 仅做密钥扫描:
#   docker run --rm -v $(pwd):/workspace -e SCAN_SECRET=true -e SCAN_DEPS=false -e SCAN_QUALITY=false code-review-assistant:latest
#
# 指定门禁阈值:
#   docker run --rm -v $(pwd):/workspace -e SEVERITY=critical code-review-assistant:latest

FROM alpine:3.19

LABEL org.opencontainers.image.title="Code Review Assistant" \
      org.opencontainers.image.description="Cloud-agnostic code review toolkit" \
      org.opencontainers.image.source="https://github.com/wzm111/code-review-assistant"

# 安装基础依赖
RUN apk add --no-cache \
    bash \
    git \
    perl \
    curl \
    python3 \
    py3-pyyaml \
    file \
    jq

# 将审查工具复制到镜像内
WORKDIR /opt/cra
COPY . /opt/cra/

# 设置环境变量默认值
ENV PATH="/opt/cra/scripts:${PATH}" \
    SEVERITY=high \
    SCAN_SECRET=true \
    SCAN_DEPS=true \
    SCAN_QUALITY=true \
    REPORT_DIR=/tmp/cra-reports

# 工作目录由运行时挂载的项目代码决定
WORKDIR /workspace

ENTRYPOINT ["/opt/cra/docker-entrypoint.sh"]
CMD ["."]
