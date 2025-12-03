#!/bin/bash
################################################################################
# BenchBase 测试脚本 - 步骤4: 执行基准测试
# 功能: 运行工作负载并收集性能指标
# 用法: ./04_run_benchmark.sh [-t benchmark_type]
################################################################################

set -e  # 遇到错误立即退出

# 颜色输出配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  BenchBase 基准测试 - ${BENCHMARK_TYPE^^}${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. 检查容器是否运行
echo -e "\n${YELLOW}[步骤 1/4]${NC} 检查 BenchBase 容器状态..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}错误: 容器 '${CONTAINER_NAME}' 未运行${NC}"
    echo -e "${YELLOW}请先运行: ./01_start_benchbase.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 容器运行正常${NC}"

# 2. 读取测试配置
echo -e "\n${YELLOW}[步骤 2/4]${NC} 读取测试配置..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CONFIG="${SCRIPT_DIR}/${CONFIG_FILE}"

if [ ! -f "${LOCAL_CONFIG}" ]; then
    echo -e "${RED}错误: 配置文件不存在: ${LOCAL_CONFIG}${NC}"
    echo -e "${YELLOW}请先运行: ./02_create_schema.sh -t ${BENCHMARK_TYPE}${NC}"
    exit 1
fi

# 提取关键参数
TERMINALS=$(grep -oP '<terminals>\K[0-9]+' "${LOCAL_CONFIG}" || echo "16")
DURATION=$(grep -oP '<time>\K[0-9]+' "${LOCAL_CONFIG}" || echo "60")
WARMUP=$(grep -oP '<warmup>\K[0-9]+' "${LOCAL_CONFIG}" || echo "10")
SCALEFACTOR=$(grep -oP '<scalefactor>\K[0-9]+' "${LOCAL_CONFIG}" || echo "10")

echo -e "${GREEN}✓ 配置读取成功${NC}"
echo -e "  ${CYAN}测试参数:${NC}"
echo -e "    - 基准测试: ${BENCHMARK_TYPE^^}"
echo -e "    - 规模因子: ${SCALEFACTOR}"
echo -e "    - 并发终端: ${TERMINALS}"
echo -e "    - 预热时间: ${WARMUP} 秒"
echo -e "    - 测试时长: ${DURATION} 秒"
echo -e "    - 总计时长: $((WARMUP + DURATION)) 秒"

# 3. 确认执行
echo -e "\n${YELLOW}[步骤 3/4]${NC} 准备开始测试..."
TOTAL_TIME=$((WARMUP + DURATION))
echo -e "${CYAN}测试将在 ${TOTAL_TIME} 秒后完成，期间请勿关闭终端${NC}"
echo -e "${YELLOW}按 Ctrl+C 可以中止测试${NC}"
echo -e "\n倒计时: 3 秒后开始..."
sleep 1
echo -e "倒计时: 2 秒后开始..."
sleep 1
echo -e "倒计时: 1 秒后开始..."
sleep 1

# 4. 执行基准测试
echo -e "\n${YELLOW}[步骤 4/4]${NC} 执行 TPC-C 基准测试..."
echo -e "${BLUE}=======================================${NC}"
echo -e "${GREEN}测试已开始! ($(date '+%Y-%m-%d %H:%M:%S'))${NC}"
echo -e "${BLUE}=======================================${NC}"

# 记录开始时间
START_TIME=$(date +%s)

# 在容器内运行 BenchBase 的 execute 命令
# 使用 2>&1 捕获所有输出并实时显示
docker exec ${CONTAINER_NAME} bash -c "
    java -jar benchbase.jar \
        -b ${BENCHMARK_TYPE} \
        -c ${CONFIG_FILE} \
        --execute=true \
        -d results/
" 2>&1 | while IFS= read -r line; do
    # 高亮关键信息
    if [[ "$line" =~ "Throughput" ]] || [[ "$line" =~ "tpmC" ]]; then
        echo -e "${GREEN}${line}${NC}"
    elif [[ "$line" =~ "Latency" ]] || [[ "$line" =~ "ms" ]]; then
        echo -e "${CYAN}${line}${NC}"
    elif [[ "$line" =~ "ERROR" ]] || [[ "$line" =~ "FAIL" ]]; then
        echo -e "${RED}${line}${NC}"
    elif [[ "$line" =~ "WARN" ]]; then
        echo -e "${YELLOW}${line}${NC}"
    else
        echo "$line"
    fi
done

# 记录结束时间
END_TIME=$(date +%s)
DURATION_ACTUAL=$((END_TIME - START_TIME))
MINUTES=$((DURATION_ACTUAL / 60))
SECONDS=$((DURATION_ACTUAL % 60))

# 检查执行结果
EXEC_STATUS=${PIPESTATUS[0]}
if [ $EXEC_STATUS -eq 0 ]; then
    echo -e "\n${BLUE}=======================================${NC}"
    echo -e "${GREEN}✓ 基准测试执行成功${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo -e "  - 实际耗时: ${MINUTES} 分 ${SECONDS} 秒"
    echo -e "  - 结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
else
    echo -e "\n${RED}✗ 基准测试执行失败 (退出码: $EXEC_STATUS)${NC}"
    exit 1
fi

# 查找最新的结果文件
echo -e "\n${YELLOW}查找测试结果文件...${NC}"
RESULTS_DIR="${SCRIPT_DIR}/results"
LATEST_RESULT=$(find "${RESULTS_DIR}" -name "*.summary.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

if [ -n "$LATEST_RESULT" ]; then
    echo -e "${GREEN}✓ 结果文件已生成${NC}"
    echo -e "  - 位置: ${LATEST_RESULT}"
    echo -e "  - 大小: $(du -h "$LATEST_RESULT" | cut -f1)"
else
    echo -e "${YELLOW}⚠ 未找到 JSON 结果文件${NC}"
fi

echo ""
