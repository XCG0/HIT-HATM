# For the devcontainer we need a full JDK.
FROM maven:3-eclipse-temurin-23 AS devcontainer

LABEL org.opencontainers.image.source="https://github.com/cmu-db/benchbase/"

# 使用阿里云镜像源加速 apt-get (DEB822 格式)
RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources \
    && sed -i 's|http://security.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources


# 安装 Python3 和 pip，并保留原有工具
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install --no-install-recommends sudo vim-nox less bash-completion git openssh-client jq python3 python3-pip \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add a containeruser that allows vscode/codespaces to map the local host user
# (often uid 1000) to some non-root user inside the container.
ARG CONTAINERUSER_UID=1000
ARG CONTAINERUSER_GID=1000
RUN groupadd --non-unique --gid ${CONTAINERUSER_GID} containergroup \
    && useradd --non-unique --create-home --no-user-group --comment 'Container User' \
    --uid ${CONTAINERUSER_UID} --gid ${CONTAINERUSER_GID} containeruser \
    && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && echo 'containeruser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN mkdir -p /benchbase/results && chown -R containeruser:containergroup /benchbase/

USER containeruser
# Unset the upstream MVN_CONFIG value - it interacts poorly with the mvnw wrapper.
ENV MAVEN_CONFIG=
ENV MAVEN_CONFIG_DIR=/home/containeruser/.m2
WORKDIR /benchbase
VOLUME /benchbase/results

# 不在构建时编译,而是在运行时按需编译
# 这样就不需要完整的 BenchBase 源代码了
ENV SHELL=/bin/bash
ENTRYPOINT ["/bin/bash", "-l"]
