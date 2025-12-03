#!/bin/bash
################################################################################
# BenchBase TPC-C 测试脚本 - 步骤1: 启动 BenchBase 容器
# 功能: 拉取官方镜像并启动 BenchBase 测试客户端容器
################################################################################

set -e  # 遇到错误立即退出

# 颜色输出配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
export MSYS_NO_PATHCONV=1
BENCHBASE_IMAGE="xcg0/benchbase-opengauss:latest"
CONTAINER_NAME="benchbase-client"
NETWORK_NAME="opengauss-network"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 配置和结果目录（相对于项目根目录）
CONFIG_DIR="${SCRIPT_DIR}/config"
RESULTS_DIR="${SCRIPT_DIR}/results"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  BenchBase TPC-C 测试环境初始化${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. 检查 Docker 网络
echo -e "\n${YELLOW}[步骤 1/5]${NC} 检查 Docker 网络..."
if ! docker network inspect ${NETWORK_NAME} >/dev/null 2>&1; then
    echo -e "${RED}错误: Docker 网络 '${NETWORK_NAME}' 不存在${NC}"
    echo -e "${YELLOW}请先运行 openGauss 集群初始化脚本${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 网络 '${NETWORK_NAME}' 已存在${NC}"

# 2. 检查 openGauss 主节点连接
echo -e "\n${YELLOW}[步骤 2/5]${NC} 检查 openGauss 主节点连接..."
PRIMARY_IP="172.18.0.10"
PRIMARY_CONTAINER="opengauss-primary"

# 方法1: 检查容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "^${PRIMARY_CONTAINER}$"; then
    echo -e "${RED}错误: openGauss 主节点容器未运行${NC}"
    echo -e "${YELLOW}提示: 请先运行 multi-node 脚本启动集群${NC}"
    exit 1
fi

# 方法2: 检查数据库进程
if docker exec ${PRIMARY_CONTAINER} bash -c "ps aux | grep gaussdb | grep -v grep" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ openGauss 主节点 (${PRIMARY_IP}) 运行正常${NC}"
else
    echo -e "${RED}错误: openGauss 数据库进程未运行${NC}"
    echo -e "${YELLOW}提示: 请检查容器日志: docker logs ${PRIMARY_CONTAINER}${NC}"
    exit 1
fi

# 方法3: 测试数据库连接（可选，更严格）
if docker exec ${PRIMARY_CONTAINER} bash -c 'su - omm -c "gsql -d postgres -p 5432 -c \"SELECT 1;\" >/dev/null 2>&1"'; then
    echo -e "${GREEN}✓ 数据库连接测试成功${NC}"
else
    echo -e "${YELLOW}⚠ 数据库进程运行中，但连接测试失败（可能正在初始化）${NC}"
fi

# 3. 创建本地目录
echo -e "\n${YELLOW}[步骤 3/5]${NC} 创建配置和结果目录..."
mkdir -p "${CONFIG_DIR}"
mkdir -p "${RESULTS_DIR}"
echo -e "${GREEN}✓ 目录创建完成${NC}"
echo "  - 配置目录: ${CONFIG_DIR}"
echo "  - 结果目录: ${RESULTS_DIR}"

# 4. BenchBase 镜像
echo -e "\n${YELLOW}[步骤 4/5]${NC} 检查 BenchBase 镜像..."
if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${BENCHBASE_IMAGE}$"; then
    echo -e "${RED}错误: 镜像不存在，请运行: docker pull $BENCHBASE_IMAGE${NC}"
    exit 1
fi

# 5. 停止并删除已存在的容器（如果有）
echo -e "\n${YELLOW}[步骤 5/5]${NC} 启动 BenchBase 容器..."
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "  - 发现已存在的容器，正在删除..."
    docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1
fi

# 启动容器（后台运行）
# 添加时区和语言环境变量
# TZ=Asia/Shanghai: 设置为中国标准时间 (UTC+8)
docker run -d \
    --name ${CONTAINER_NAME} \
    --network ${NETWORK_NAME} \
    -e TZ=Asia/Shanghai \
    -e LC_ALL=C \
    -v "${CONFIG_DIR}:/benchbase/config" \
    -v "${RESULTS_DIR}:/benchbase/results" \
    --workdir /benchbase \
    ${BENCHBASE_IMAGE} \
    sleep infinity

# 检查容器状态
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${GREEN}✓ BenchBase 容器启动成功${NC}"
else
    echo -e "${RED}错误: 容器启动失败${NC}"
    exit 1
fi

# 显示容器信息
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  环境初始化完成!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "容器名称: ${CONTAINER_NAME}"
echo -e "网络: ${NETWORK_NAME}"
echo -e "配置目录: ${CONFIG_DIR}"
echo -e "结果目录: ${RESULTS_DIR}"
echo ""
