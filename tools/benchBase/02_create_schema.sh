#!/bin/bash
################################################################################
# BenchBase 测试脚本 - 步骤2: 创建 Schema
# 功能: 初始化基准测试所需的数据库表结构
# 用法: ./02_create_schema.sh [-t benchmark_type]
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="benchbase-client"
BENCHMARK_TYPE="tpcc"  # 默认使用 TPC-C

# 参数解析
while getopts "t:h" opt; do
    case $opt in
        t)
            BENCHMARK_TYPE="$OPTARG"
            ;;
        \?)
            echo -e "${RED}无效选项: -$OPTARG${NC}" >&2
            exit 1
            ;;
    esac
done

# 根据基准测试类型设置配置文件
CONFIG_FILE="config/${BENCHMARK_TYPE}_config.xml"

# 数据库配置
DB_HOST="172.18.0.10"
DB_PORT="5432"
DB_NAME="benchbase_db"
DB_USER="benchbase"
DB_PASSWORD="benchbase@123"
OPENGAUSS_CONTAINER="opengauss-primary"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  BenchBase Schema 创建 - ${BENCHMARK_TYPE^^}${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. 检查容器是否运行
echo -e "\n${YELLOW}[步骤 1/5]${NC} 检查 BenchBase 容器状态..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}错误: 容器 '${CONTAINER_NAME}' 未运行${NC}"
    echo -e "${YELLOW}请先运行: ./01_start_benchbase.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 容器运行正常${NC}"

# 2. 检查 openGauss 主节点
echo -e "\n${YELLOW}[步骤 2/5]${NC} 检查 openGauss 主节点..."
if ! docker ps --format '{{.Names}}' | grep -q "^${OPENGAUSS_CONTAINER}$"; then
    echo -e "${YELLOW}警告: openGauss 主节点容器未运行${NC}"
    
    # 检查集群启动脚本是否存在
    CLUSTER_START_SCRIPT="${SCRIPT_DIR}/../multi-node/04_start_cluster.sh"
    if [ -f "${CLUSTER_START_SCRIPT}" ]; then
        echo -e "${BLUE}→ 正在自动启动 openGauss 集群...${NC}"
        bash "${CLUSTER_START_SCRIPT}"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ openGauss 集群启动成功${NC}"
            sleep 2  # 等待数据库完全就绪
        else
            echo -e "${RED}错误: openGauss 集群启动失败${NC}"
            exit 1
        fi
    else
        echo -e "${RED}错误: 找不到集群启动脚本: ${CLUSTER_START_SCRIPT}${NC}"
        echo -e "${YELLOW}请手动运行: cd tools/multi-node && ./04_start_cluster.sh${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ openGauss 主节点运行正常${NC}"
fi

# 3. 创建数据库和用户
echo -e "\n${YELLOW}[步骤 3/5]${NC} 创建 BenchBase 数据库和用户..."

# 检查业务数据库是否存在
DB_EXISTS=$(docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
    gsql -d postgres -t -A -c \"SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'\"
" 2>&1 | grep -o "1" || echo "0")

if [ "$DB_EXISTS" == "1" ]; then
    # 数据库存在，先断开所有连接，然后删除并重建
    echo -e "${YELLOW}数据库已存在，正在清空...${NC}"
    docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
        gsql -d postgres -c \"
            SELECT pg_terminate_backend(pid) 
            FROM pg_stat_activity 
            WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();
        \" > /dev/null 2>&1;
        gsql -d postgres -c \"DROP DATABASE IF EXISTS ${DB_NAME}\" > /dev/null 2>&1;
        gsql -d postgres -c \"CREATE DATABASE ${DB_NAME} ENCODING 'UTF8'\" > /dev/null 2>&1;
    " || {
        echo -e "${RED}✗ 数据库清空失败${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ 数据库已清空并重建${NC}"
else
    # 数据库不存在，创建新数据库
    docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
        gsql -d postgres -c \"CREATE DATABASE ${DB_NAME} ENCODING 'UTF8'\"
    " > /dev/null 2>&1 || {
        echo -e "${RED}✗ 数据库创建失败${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ 数据库已创建${NC}"
fi

# 检查用户是否存在，不存在则创建
USER_EXISTS=$(docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
    gsql -d postgres -t -A -c \"SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}'\"
" 2>&1 | grep -o "1" || echo "0")

if [ "$USER_EXISTS" != "1" ]; then
    docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
        gsql -d postgres -c \"CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}'\"
    " > /dev/null 2>&1 || {
        echo -e "${RED}✗ 用户创建失败${NC}"
        exit 1
    }
fi

# 授予数据库权限
docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
    gsql -d postgres -c \"GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER}\" && \
    gsql -d ${DB_NAME} -c \"GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER}\" && \
    gsql -d ${DB_NAME} -c \"ALTER SCHEMA public OWNER TO ${DB_USER}\"
" > /dev/null 2>&1

echo -e "${GREEN}✓ 数据库和用户配置完成${NC}"

# 4. 创建 PostgreSQL 兼容视图（解决 openGauss 兼容性问题）
echo -e "\n${YELLOW}[步骤 4/6]${NC} 创建 PostgreSQL 兼容视图..."
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

# 5. 检查配置文件
echo -e "\n${YELLOW}[步骤 5/6]${NC} 检查配置文件..."
LOCAL_CONFIG="${SCRIPT_DIR}/${CONFIG_FILE}"

if [ ! -f "${LOCAL_CONFIG}" ]; then
    echo -e "${RED}错误: 配置文件不存在: ${LOCAL_CONFIG}${NC}"
    echo -e "${YELLOW}请确认已创建 ${BENCHMARK_TYPE} 的配置文件${NC}"
    echo -e "${YELLOW}提示: 可以从 config/postgres/sample_${BENCHMARK_TYPE}_config.xml 复制并修改${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 配置文件存在: ${CONFIG_FILE}${NC}"

# 6. 执行 Schema 创建
echo -e "\n${YELLOW}[步骤 6/6]${NC} 创建 ${BENCHMARK_TYPE^^} 数据库 Schema..."
echo -e "${BLUE}正在执行 DDL 语句（这可能需要几分钟）...${NC}"

# 在容器内运行 BenchBase 的 create 命令
# 注意: 对于某些基准测试（如 chbenchmark），表的创建会在 load 阶段自动完成
# 这里只做清空操作，确保数据库是干净的
docker exec ${CONTAINER_NAME} bash -c "
    java -jar benchbase.jar \
        -b ${BENCHMARK_TYPE} \
        -c ${CONFIG_FILE} \
        --create=true \
        --clear=true
"

# 检查执行结果
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Schema 创建成功${NC}"
    echo -e "${YELLOW}注意: 某些基准测试的表结构会在数据加载阶段自动创建${NC}"
    
    # Wikipedia 基准测试的特殊修复：允许 NULL 值
    if [ "${BENCHMARK_TYPE}" = "wikipedia" ]; then
        echo -e "\n${CYAN}→ 应用 Wikipedia 基准测试的兼容性修复...${NC}"
        docker exec ${OPENGAUSS_CONTAINER} su - omm -c "
            gsql -d ${DB_NAME} -c \"
                -- 修复 useracct 表的 NOT NULL 约束问题
                -- BenchBase 的 Wikipedia 数据加载器会插入包含 NULL 值的记录
                ALTER TABLE useracct ALTER COLUMN user_real_name DROP NOT NULL;
                ALTER TABLE useracct ALTER COLUMN user_password DROP NOT NULL;
                ALTER TABLE useracct ALTER COLUMN user_newpassword DROP NOT NULL;
                ALTER TABLE useracct ALTER COLUMN user_email DROP NOT NULL;
                ALTER TABLE useracct ALTER COLUMN user_options DROP NOT NULL;
                ALTER TABLE useracct ALTER COLUMN user_touched DROP NOT NULL;
                ALTER TABLE useracct ALTER COLUMN user_token DROP NOT NULL;
                
                -- 修复 recentchanges 表的 NOT NULL 约束问题
                ALTER TABLE recentchanges ALTER COLUMN rc_moved_to_title DROP NOT NULL;
                ALTER TABLE recentchanges ALTER COLUMN rc_user_text DROP NOT NULL;
                ALTER TABLE recentchanges ALTER COLUMN rc_comment DROP NOT NULL;
                ALTER TABLE recentchanges ALTER COLUMN rc_ip DROP NOT NULL;
                
                -- 修复 logging 表的 NOT NULL 约束问题
                ALTER TABLE logging ALTER COLUMN log_comment DROP NOT NULL;
            \" > /dev/null 2>&1
        "
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Wikipedia 兼容性修复完成（已移除关键列的 NOT NULL 约束）${NC}"
        else
            echo -e "${YELLOW}⚠ 部分修复可能失败，但不影响继续${NC}"
        fi
    fi
else
    echo -e "\n${RED}✗ Schema 创建失败${NC}"
    exit 1
fi
echo ""
