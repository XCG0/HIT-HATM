#!/bin/bash
################################################################################
# CHBenchmark 专用 Schema 创建脚本
# 功能: 先创建 TPC-C 的表结构，再添加 TPC-H 的额外表
# 说明: CHBenchmark = TPC-C + TPC-H，需要两步初始化
################################################################################

set -e  # 遇到错误立即退出

# 颜色输出配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
export MSYS_NO_PATHCONV=1
CONTAINER_NAME="benchbase-client"
OPENGAUSS_CONTAINER="opengauss-primary"

# 数据库配置
DB_HOST="172.18.0.10"
DB_PORT="5432"
DB_NAME="benchbase_db"
DB_USER="benchbase"
DB_PASSWORD="benchbase@123"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  CHBenchmark Schema 创建 (两阶段)${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. 检查容器是否运行
echo -e "\n${YELLOW}[步骤 1/6]${NC} 检查容器状态..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}错误: 容器 '${CONTAINER_NAME}' 未运行${NC}"
    exit 1
fi
if ! docker ps --format '{{.Names}}' | grep -q "^${OPENGAUSS_CONTAINER}$"; then
    echo -e "${RED}错误: openGauss 主节点容器未运行${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 所有容器运行正常${NC}"

# 2. 创建数据库
echo -e "\n${YELLOW}[步骤 2/6]${NC} 准备数据库..."
DB_EXISTS=$(docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
    gsql -d postgres -t -A -c \"SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'\"
" 2>&1 | grep -o "1" || echo "0")

if [ "$DB_EXISTS" == "1" ]; then
    echo -e "${YELLOW}数据库已存在，正在清空...${NC}"
    docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
        gsql -d postgres -c \"
            SELECT pg_terminate_backend(pid) 
            FROM pg_stat_activity 
            WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();
        \" > /dev/null 2>&1;
        gsql -d postgres -c \"DROP DATABASE IF EXISTS ${DB_NAME}\" > /dev/null 2>&1;
        gsql -d postgres -c \"CREATE DATABASE ${DB_NAME} ENCODING 'UTF8'\" > /dev/null 2>&1;
    "
    echo -e "${GREEN}✓ 数据库已清空并重建${NC}"
else
    docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
        gsql -d postgres -c \"CREATE DATABASE ${DB_NAME} ENCODING 'UTF8'\"
    " > /dev/null 2>&1
    echo -e "${GREEN}✓ 数据库已创建${NC}"
fi

# 检查并创建用户
USER_EXISTS=$(docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
    gsql -d postgres -t -A -c \"SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}'\"
" 2>&1 | grep -o "1" || echo "0")

if [ "$USER_EXISTS" != "1" ]; then
    docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
        gsql -d postgres -c \"CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}'\"
    " > /dev/null 2>&1
fi

# 授予权限
docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
    gsql -d postgres -c \"GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER}\" && \
    gsql -d ${DB_NAME} -c \"GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER}\" && \
    gsql -d ${DB_NAME} -c \"ALTER SCHEMA public OWNER TO ${DB_USER}\"
" > /dev/null 2>&1

echo -e "${GREEN}✓ 数据库权限配置完成${NC}"

# 3. 创建 PostgreSQL 兼容视图（解决 openGauss 兼容性问题）
echo -e "\n${YELLOW}[步骤 3/7]${NC} 创建 PostgreSQL 兼容视图..."
echo -e "${CYAN}→ 解决 BenchBase DBCollector 的 openGauss 兼容性问题${NC}"

# 创建 pg_stat_archiver 兼容视图
docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
    gsql -d ${DB_NAME} -c \"
        -- 删除已存在的视图
        DROP VIEW IF EXISTS pg_stat_archiver CASCADE;
        
        -- 创建兼容视图（返回空数据，避免查询错误）
        CREATE OR REPLACE VIEW pg_stat_archiver AS
        SELECT
            0::bigint AS archived_count,
            ''::text AS last_archived_wal,
            NULL::timestamp AS last_archived_time,
            0::bigint AS failed_count,
            ''::text AS last_failed_wal,
            NULL::timestamp AS last_failed_time,
            NULL::timestamp AS stats_reset;
        
        -- 授权给 benchbase 用户
        GRANT SELECT ON pg_stat_archiver TO ${DB_USER};
    \"
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 兼容视图创建成功${NC}"
else
    echo -e "${YELLOW}⚠ 兼容视图创建失败（可能不影响测试）${NC}"
fi

# 4. 创建 TPC-C Schema（这是 CHBenchmark 的基础）
echo -e "\n${YELLOW}[步骤 4/7]${NC} 创建 TPC-C 基础表结构..."
docker exec ${CONTAINER_NAME} bash -c "
    java -jar benchbase.jar \
        -b tpcc \
        -c config/tpcc_config.xml \
        --create=true
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ TPC-C 表结构创建成功${NC}"
else
    echo -e "${RED}✗ TPC-C 表结构创建失败${NC}"
    exit 1
fi

# 5. 验证 TPC-C 表
echo -e "\n${YELLOW}[步骤 5/7]${NC} 验证 TPC-C 表..."
TPCC_TABLES=$(docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
    gsql -d ${DB_NAME} -t -A -c \"
        SELECT COUNT(*) FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename IN ('warehouse', 'district', 'customer', 'item', 'stock', 'oorder', 'order_line', 'new_order', 'history')
    \"
" 2>&1 | grep -o "[0-9]*" | head -1)

echo -e "  - TPC-C 表数量: ${TPCC_TABLES}/9"
if [ "$TPCC_TABLES" -eq 9 ]; then
    echo -e "${GREEN}✓ 所有 TPC-C 表已创建${NC}"
else
    echo -e "${RED}✗ TPC-C 表创建不完整${NC}"
    exit 1
fi

# 6. 添加 CHBenchmark 的额外表（TPC-H 部分）
echo -e "\n${YELLOW}[步骤 6/7]${NC} 添加 TPC-H 额外表..."
docker exec ${CONTAINER_NAME} bash -c "
    java -jar benchbase.jar \
        -b chbenchmark \
        -c config/chbenchmark_config.xml \
        --create=true
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ TPC-H 额外表创建成功${NC}"
else
    echo -e "${YELLOW}⚠ TPC-H 表创建可能有问题（但可以继续）${NC}"
fi

# 7. 最终验证
echo -e "\n${YELLOW}[步骤 7/7]${NC} 验证完整 Schema..."
ALL_TABLES=$(docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
    gsql -d ${DB_NAME} -c '\dt'
" 2>&1)

echo -e "${CYAN}已创建的表:${NC}"
echo "$ALL_TABLES"
echo ""
