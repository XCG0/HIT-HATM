#!/bin/bash
# openGauss 多节点集群 - Docker 容器创建脚本 (Linux/macOS)
# 创建一主两备的集群环境

set -e

echo "=== openGauss 多节点集群部署 ==="
echo ""

# 检查镜像是否存在
IMAGE_NAME="xcg0/opengauss-openeuler_22.03:x86_64"
echo "检查镜像: $IMAGE_NAME"
if ! docker images -q $IMAGE_NAME | grep -q .; then
    echo "错误: 镜像 $IMAGE_NAME 不存在，请先拉取镜像"
    echo "运行: docker pull $IMAGE_NAME"
    exit 1
fi
echo "✓ 镜像已存在"
echo ""

# 停止并删除已存在的容器（如果有）
echo "清理已存在的容器..."
for container in opengauss-primary opengauss-standby1 opengauss-standby2; do
    if docker ps -a -q -f name=$container | grep -q .; then
        echo "  停止并删除容器: $container"
        docker stop $container 2>/dev/null || true
        docker rm $container 2>/dev/null || true
    fi
done
echo "✓ 清理完成"
echo ""

# 删除已存在的网络（如果有）
echo "检查 Docker 网络..."
if docker network ls -q -f name=opengauss-network | grep -q .; then
    echo "  删除已存在的网络: opengauss-network"
    docker network rm opengauss-network 2>/dev/null || true
fi

# 创建自定义网络
echo "创建 Docker 网络: opengauss-network (172.18.0.0/16)"
docker network create \
    --driver bridge \
    --subnet=172.18.0.0/16 \
    --gateway=172.18.0.1 \
    opengauss-network

echo "✓ 网络创建成功"
echo ""

# 创建主节点
echo "创建主节点容器: opengauss-primary (172.18.0.10)"
docker run -itd \
    --name opengauss-primary \
    --hostname primary \
    --network opengauss-network \
    --ip 172.18.0.10 \
    --privileged=true \
    -p 127.0.0.1:15432:5432 \
    $IMAGE_NAME

echo "✓ 主节点创建成功"
echo ""

# 创建备节点1
echo "创建备节点1容器: opengauss-standby1 (172.18.0.11)"
docker run -itd \
    --name opengauss-standby1 \
    --hostname standby1 \
    --network opengauss-network \
    --ip 172.18.0.11 \
    --privileged=true \
    -p 127.0.0.1:15433:5432 \
    $IMAGE_NAME

echo "✓ 备节点1创建成功"
echo ""

# 创建备节点2
echo "创建备节点2容器: opengauss-standby2 (172.18.0.12)"
docker run -itd \
    --name opengauss-standby2 \
    --hostname standby2 \
    --network opengauss-network \
    --ip 172.18.0.12 \
    --privileged=true \
    -p 127.0.0.1:15434:5432 \
    $IMAGE_NAME

echo "✓ 备节点2创建成功"
echo ""

# 验证容器状态
echo "=== 容器状态 ==="
docker ps -f "name=opengauss-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 验证网络配置
echo "=== 网络配置 ==="
docker network inspect opengauss-network --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
echo ""

echo "=== 部署成功 ==="
echo "下一步: 配置 SSH 互信"
echo "运行: docker exec -it opengauss-primary bash"
echo "然后在容器内运行: cd /home/scripts && bash 02_setup_ssh.sh"
