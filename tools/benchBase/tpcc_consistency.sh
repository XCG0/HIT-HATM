#!/bin/bash
################################################################################
# BenchBase 一致性校验脚本
# 功能: 在TPC-C压力测试后运行数据一致性检查
# 用法: ./05_run_consistency_check.sh
################################################################################

set -e  # 遇到错误立即退出

# 颜色输出配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
CONTAINER_NAME="benchbase-client"
BENCHMARK_TYPE="tpcc-consistency-checker"  # 一致性检查专用类型
CONFIG_FILE="config/tpcc_consistency_check.xml"  # 一致性检查配置文件

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TPC-C 数据一致性校验${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. 检查容器是否运行
echo -e "\n${YELLOW}[步骤 1/4]${NC} 检查 BenchBase 容器状态..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}错误: 容器 '${CONTAINER_NAME}' 未运行${NC}"
    echo -e "${YELLOW}请先运行: ./01_start_benchbase.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 容器运行正常${NC}"

# 2. 检查配置文件
echo -e "\n${YELLOW}[步骤 2/4]${NC} 检查配置文件..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CONFIG="${SCRIPT_DIR}/${CONFIG_FILE}"

if [ ! -f "${LOCAL_CONFIG}" ]; then
    echo -e "${RED}错误: 一致性校验配置文件不存在: ${LOCAL_CONFIG}${NC}"
    echo -e "${YELLOW}请确保已创建 tpcc_consistency_check.xml 配置文件${NC}"
    exit 1
fi

# 提取关键参数
SCALEFACTOR=$(grep -oP '<scalefactor>\K[0-9]+' "${LOCAL_CONFIG}" || echo "10")
CREATE_FLAG=$(grep -oP '<create>\K(true|false)' "${LOCAL_CONFIG}" || echo "false")
LOAD_FLAG=$(grep -oP '<load>\K(true|false)' "${LOCAL_CONFIG}" || echo "false")

echo -e "${GREEN}✓ 配置读取成功${NC}"
echo -e "  ${CYAN}校验参数:${NC}"
echo -e "    - 检查类型: ${BENCHMARK_TYPE}"
echo -e "    - 仓库数量: ${SCALEFACTOR}"
echo -e "    - 创建表: ${CREATE_FLAG}"
echo -e "    - 加载数据: ${LOAD_FLAG}"

# 3. 警告检查
echo -e "\n${YELLOW}[步骤 3/4]${NC} 安全性检查..."

if [ "${CREATE_FLAG}" = "true" ]; then
    echo -e "${RED}警告: 配置文件中的 <create> 参数为 true${NC}"
    echo -e "${RED}这将删除现有表并创建新表，可能导致数据丢失！${NC}"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}操作已取消${NC}"
        exit 0
    fi
fi

if [ "${LOAD_FLAG}" = "true" ]; then
    echo -e "${RED}警告: 配置文件中的 <load> 参数为 true${NC}"
    echo -e "${RED}这将清空现有数据并重新加载，可能导致数据丢失！${NC}"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}操作已取消${NC}"
        exit 0
    fi
fi

# 4. 执行一致性校验
echo -e "\n${YELLOW}[步骤 4/4]${NC} 执行 TPC-C 数据一致性校验..."
echo -e "${BLUE}=======================================${NC}"
echo -e "${GREEN}校验已开始! ($(date '+%Y-%m-%d %H:%M:%S'))${NC}"
echo -e "${BLUE}=======================================${NC}"

# 记录开始时间
START_TIME=$(date +%s)

# 在容器内运行一致性检查
# 注意: 不需要 --execute=true，因为一致性检查是自动执行的
docker exec ${CONTAINER_NAME} bash -c "
    java -jar benchbase.jar \
        -b ${BENCHMARK_TYPE} \
        -c ${CONFIG_FILE}
" 2>&1 | while IFS= read -r line; do
    # 高亮关键信息
    if [[ "$line" =~ "Condition.*PASS" ]] || [[ "$line" =~ "所有一致性条件通过" ]]; then
        echo -e "${GREEN}${line}${NC}"
    elif [[ "$line" =~ "Condition.*FAIL" ]] || [[ "$line" =~ "一致性条件失败" ]]; then
        echo -e "${RED}${line}${NC}"
    elif [[ "$line" =~ "ERROR" ]] || [[ "$line" =~ "FAIL" ]]; then
        echo -e "${RED}${line}${NC}"
    elif [[ "$line" =~ "WARN" ]]; then
        echo -e "${YELLOW}${line}${NC}"
    elif [[ "$line" =~ "检查完成" ]] || [[ "$line" =~ "Consistency check" ]]; then
        echo -e "${CYAN}${line}${NC}"
    else
        echo "$line"
    fi
done

# 记录结束时间
END_TIME=$(date +%s)
DURATION_ACTUAL=$((END_TIME - START_TIME))

# 检查执行结果
EXEC_STATUS=${PIPESTATUS[0]}
if [ $EXEC_STATUS -eq 0 ]; then
    echo -e "\n${BLUE}=======================================${NC}"
    echo -e "${GREEN}✓ 一致性校验执行成功${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo -e "  - 耗时: ${DURATION_ACTUAL} 秒"
    echo -e "  - 结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
else
    echo -e "\n${RED}✗ 一致性校验执行失败 (退出码: $EXEC_STATUS)${NC}"
    exit 1
fi

# 查找最新的结果文件
echo -e "\n${YELLOW}查找校验结果文件...${NC}"
RESULTS_DIR="${SCRIPT_DIR}/results"
LATEST_RESULT=$(find "${RESULTS_DIR}" -name "*consistency*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

if [ -n "$LATEST_RESULT" ]; then
    echo -e "${GREEN}✓ 结果文件已生成${NC}"
    echo -e "  - 位置: ${LATEST_RESULT}"
    echo -e "  - 大小: $(du -h "$LATEST_RESULT" | cut -f1)"
    
    # 检查是否有失败的条件
    FAILED_COUNT=$(grep -c '"FAILED"' "$LATEST_RESULT" 2>/dev/null || echo "0")
    if [ "$FAILED_COUNT" -gt 0 ]; then
        echo -e "${RED}⚠ 发现 ${FAILED_COUNT} 个失败的一致性条件${NC}"
        echo -e "${YELLOW}详细失败信息请查看: ${LATEST_RESULT}${NC}"
    else
        echo -e "${GREEN}✓ 所有一致性条件通过检查${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 未找到一致性检查结果文件${NC}"
fi

echo ""