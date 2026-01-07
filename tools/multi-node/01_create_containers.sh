#!/bin/bash
# openGauss 多节点集群 - Docker 容器创建脚本
set -e

# 默认备节点数量
STANDBY_COUNT=2

# 解析命令行参数
while getopts "n:h" opt; do
    case $opt in
        n) STANDBY_COUNT=$OPTARG ;;
        h)
            echo "用法: $0 -n [备节点数量]"
            echo "示例: $0 -n 2  # 创建1主2备"
            exit 0
            ;;
        \?) echo "错误: 无效选项 -$OPTARG"; exit 1 ;;
        :) echo "错误: 选项 -$OPTARG 需要参数"; exit 1 ;;
    esac
done

# 验证参数
if ! [[ "$STANDBY_COUNT" =~ ^[0-9]+$ ]] || [ "$STANDBY_COUNT" -lt 1 ] || [ "$STANDBY_COUNT" -gt 10 ]; then
    echo "错误: 备节点数量必须是 1-10 之间的整数"
    exit 1
fi

echo "[1/5] 准备环境 (1主+${STANDBY_COUNT}备)"

# 获取脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INIT_SCRIPT="$PROJECT_ROOT/scripts/init-container.sh"

# 检查文件
if [ ! -f "$INIT_SCRIPT" ]; then
    echo "错误: 找不到 init-container.sh"
    exit 1
fi

# 检查镜像
IMAGE_NAME="xcg0/opengauss-openeuler_22.03:x86_64"
if ! docker images -q $IMAGE_NAME | grep -q .; then
    echo "错误: 镜像不存在，请运行: docker pull $IMAGE_NAME"
    exit 1
fi


echo "[2/5] 清理旧容器"
# 清理主节点
docker stop opengauss-primary > /dev/null 2>&1 || true
docker rm opengauss-primary > /dev/null 2>&1 || true
# 清理备节点
for i in $(seq 1 10); do
    docker stop opengauss-standby$i > /dev/null 2>&1 || true
    docker rm opengauss-standby$i > /dev/null 2>&1 || true
done
echo "  ✓ 清理完成"

echo "[3/5] 创建网络"
# 删除旧网络(如果存在)
if docker network inspect opengauss-network > /dev/null 2>&1; then
    echo "  - 删除已存在的网络..."
    docker network rm opengauss-network > /dev/null 2>&1 || {
        echo "  ⚠ 网络删除失败,可能有容器仍在使用"
        echo "  - 检查并清理相关容器..."
        docker ps -a --filter network=opengauss-network --format "{{.Names}}" | while read container; do
            echo "    停止容器: $container"
            docker stop "$container" > /dev/null 2>&1 || true
            docker rm "$container" > /dev/null 2>&1 || true
        done
        echo "  - 重新尝试删除网络..."
        docker network rm opengauss-network > /dev/null 2>&1 || true
    }
fi

# 创建新网络
if ! docker network inspect opengauss-network > /dev/null 2>&1; then
    docker network create --driver bridge --subnet=172.18.0.0/16 --gateway=172.18.0.1 opengauss-network > /dev/null
fi
echo "  ✓ 网络创建完成"

TOTAL_NODES=$((1 + STANDBY_COUNT))
CURRENT_NODE=0

echo "[4/5] 创建容器 (${TOTAL_NODES}个)"

# 创建主节点
CURRENT_NODE=$((CURRENT_NODE + 1))
printf "  [%d/%d] primary ... " $CURRENT_NODE $TOTAL_NODES

MSYS_NO_PATHCONV=1 docker run -itd \
    --name opengauss-primary \
    --hostname primary \
    --network opengauss-network \
    --ip 172.18.0.10 \
    --privileged=true \
    -p 127.0.0.1:15432:5432 \
    -v "${INIT_SCRIPT}:/home/init-container.sh:ro" \
    xcg0/opengauss-openeuler_22.03:x86_64 \
    bash /home/init-container.sh > /dev/null

echo "✓"

# 创建备节点
for i in $(seq 1 $STANDBY_COUNT); do
    CURRENT_NODE=$((CURRENT_NODE + 1))
    STANDBY_IP="172.18.0.$((10 + i))"
    STANDBY_PORT="$((15432 + i))"
    STANDBY_NAME="opengauss-standby$i"
    
    printf "  [%d/%d] standby%d ... " $CURRENT_NODE $TOTAL_NODES $i
    
    MSYS_NO_PATHCONV=1 docker run -itd \
        --name $STANDBY_NAME \
        --hostname standby$i \
        --network opengauss-network \
        --ip $STANDBY_IP \
        --privileged=true \
        -p 127.0.0.1:${STANDBY_PORT}:5432 \
        -v "${INIT_SCRIPT}:/home/init-container.sh:ro" \
        xcg0/opengauss-openeuler_22.03:x86_64 \
        bash /home/init-container.sh > /dev/null
    
    echo "✓"
done

echo "[5/5] 完成"
echo "  ✓ 容器创建完成"