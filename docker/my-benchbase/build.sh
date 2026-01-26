#!/bin/bash
################################################################################
# 使用国内镜像源构建 BenchBase 镜像（只构建 postgres profile）
# 推送到 Docker Hub: xcg0/benchbase-postgres
################################################################################

set -e
export MSYS_NO_PATHCONV=1

echo "========================================"
echo "  构建 BenchBase (使用阿里云镜像源)"
echo "========================================"
echo ""

# 设置环境变量
export CONTAINERUSER_UID=1000
export CONTAINERUSER_GID=1000
export BENCHBASE_PROFILES="postgres"
export http_proxy="${http_proxy:-http://127.0.0.1:7890}"
export https_proxy="${https_proxy:-http://127.0.0.1:7890}"

echo "配置:"
echo "  - Profile: ${BENCHBASE_PROFILES}"
echo "  - UID/GID: ${CONTAINERUSER_UID}/${CONTAINERUSER_GID}"
echo "  - 代理: $http_proxy"
echo ""

# 切换到脚本所在目录
cd "$(dirname "$0")"

# 构建基础 dev 镜像(不包含编译后的代码)
echo "构建 BenchBase 基础镜像..."
echo "注意: 镜像不包含预编译的代码,将在首次运行时自动编译"
echo ""
docker build --progress=plain \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --build-arg "http_proxy=${http_proxy}" \
    --build-arg "https_proxy=${https_proxy}" \
    --build-arg "CONTAINERUSER_UID=${CONTAINERUSER_UID}" \
    --build-arg "CONTAINERUSER_GID=${CONTAINERUSER_GID}" \
    --tag benchbase:latest \
    -f Dockerfile \
    .

echo ""
echo "========================================"
echo "  构建完成!"
echo "========================================"
echo ""
echo "生成的镜像:"
docker images | grep -E "benchbase|REPOSITORY"
echo ""

# ================== 极简镜像自动化流程 ==================
echo ""
echo "========================================"
echo "  开始制作极简 BenchBase 镜像 (opengauss)"
echo "========================================"

# 1. 创建临时容器
CONTAINER_NAME=benchbase-tmp
docker rm -f $CONTAINER_NAME 2>/dev/null || true
docker run -itd --name $CONTAINER_NAME --entrypoint /bin/sh benchbase:latest -c "while true; do sleep 3600; done"

# 2. 编译 benchbase 并解压 jar
echo "[容器内] 编译 benchbase..."
docker exec $CONTAINER_NAME bash -c '
    set -e
    export http_proxy="http://host.docker.internal:7890"
    export https_proxy="http://host.docker.internal:7890"
    
    BENCHBASE_REPO="https://github.com/cmu-db/benchbase.git"
    BENCHBASE_BRANCH="main"
    if [ -d /benchbase/src ]; then
      rm -rf /benchbase/src
    fi

    echo "[容器内] 配置 Git..."
    git config --global http.postBuffer 524288000
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
    
    echo "[容器内] 正在克隆 benchbase 源码..."
    git clone --depth=1 --branch "$BENCHBASE_BRANCH" "$BENCHBASE_REPO" /benchbase/src
    cd /benchbase/src

    echo "[容器内] 正在编译 benchbase 源码..."
    ./mvnw clean package -Ppostgres -DskipTests

    # 解压并部署 benchbase
    echo "[容器内] 解压 benchbase 发布包..."
    cd /benchbase/src/target
    
    if [ -f benchbase-postgres.tgz ]; then
        tar -xzf benchbase-postgres.tgz
        BENCHBASE_DIR="benchbase-postgres"
    elif [ -f benchbase-postgres.zip ]; then
        unzip -q benchbase-postgres.zip
        BENCHBASE_DIR="benchbase-postgres"
    else
        echo "错误: 未找到 benchbase-postgres 压缩包" >&2
        exit 1
    fi
    
    echo "[容器内] 移动 benchbase 文件到 /benchbase/..."
    cd /benchbase/src/target/$BENCHBASE_DIR
    cp -r * /benchbase/
    
    echo "[容器内] benchbase 部署完成"
    ls -lh /benchbase/
'

# 3. 清理不必要文件
echo "[容器内] 清理无用文件..."
docker exec $CONTAINER_NAME bash -c '
    rm -rf /home/containeruser
    rm -rf /tmp/*
    rm -rf /var/cache/apt/archives/*
    rm -rf /var/lib/apt/lists/*
    rm -rf /usr/share/doc
    rm -rf /usr/share/man
    rm -rf /usr/share/locale
    rm -rf /usr/share/zoneinfo
    rm -rf /usr/share/maven
    rm -rf /usr/share/java
    rm -rf /usr/local/share/.cache
    rm -rf /benchbase/.m2
    rm -rf /benchbase/.git
' > /dev/null 2>&1
echo "[容器内] 清理完成"

# 4. 打包成镜像
echo "[主机] commit 镜像..."
docker commit \
    --change='ENTRYPOINT [""]' \
    --change='CMD ["sleep", "infinity"]' \
    --change='WORKDIR /benchbase' \
    $CONTAINER_NAME xcg0/benchbase-opengauss:latest

# 5. 清理临时容器
# docker rm -f $CONTAINER_NAME

echo "========================================"
echo "  镜像 xcg0/benchbase-opengauss:latest 构建完成!"
echo "========================================"
docker images | grep benchbase
echo ""

