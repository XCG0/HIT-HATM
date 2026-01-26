#!/bin/bash
# build_and_prepare_tpcc_env.sh
set -e

MSYS_NO_PATHCONV=1
IMAGE_NAME="my-benchsql:latest"
CONTAINER_NAME="my-benchsql-tpcc"
DOCKERFILE_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_PORT=5432
CONTAINER_PORT=5432

# 1. 构建镜像
echo "[1/4] 构建 Docker 镜像..."
# docker build -t $IMAGE_NAME "$DOCKERFILE_DIR"
# docker build --no-cache -t $IMAGE_NAME "$DOCKERFILE_DIR"

# 2. 启动容器（如需挂载数据卷可加 -v 参数）
echo "[2/4] 启动容器..."
docker rm -f $CONTAINER_NAME 2>/dev/null || true
docker run -d --name $CONTAINER_NAME -p $HOST_PORT:$CONTAINER_PORT $IMAGE_NAME sleep infinity

# 3. 容器内执行环境准备脚本
echo "[3/4] 容器内自动配置 TPCC 环境..."
MSYS_NO_PATHCONV=1 docker exec $CONTAINER_NAME bash '/home/benchmarksql/build_tpcc_env.sh' all

# 4. （可选）运行 TPCC 测试
# echo "[4/4] 运行 TPCC 测试..."
# docker exec $CONTAINER_NAME bash /home/benchmarksql/run_tpcc.sh run

echo "环境准备完成，可用 run_tpcc.sh 进行 TPCC 测试。"