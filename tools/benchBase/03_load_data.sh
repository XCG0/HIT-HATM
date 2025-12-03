#!/bin/bash
################################################################################
# BenchBase 测试脚本 - 步骤3: 加载测试数据
# 功能: 批量插入基准测试数据到 openGauss 数据库
# 用法: ./03_load_data.sh [-t benchmark_type]
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
echo -e "${BLUE}  BenchBase 数据加载 - ${BENCHMARK_TYPE^^}${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. 检查容器是否运行
echo -e "\n${YELLOW}[步骤 1/3]${NC} 检查 BenchBase 容器状态..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}错误: 容器 '${CONTAINER_NAME}' 未运行${NC}"
    echo -e "${YELLOW}请先运行: ./01_start_benchbase.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 容器运行正常${NC}"

# 2. 读取配置文件获取数据规模
echo -e "\n${YELLOW}[步骤 2/3]${NC} 读取配置参数..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CONFIG="${SCRIPT_DIR}/${CONFIG_FILE}"

if [ ! -f "${LOCAL_CONFIG}" ]; then
    echo -e "${RED}错误: 配置文件不存在: ${LOCAL_CONFIG}${NC}"
    echo -e "${YELLOW}请先运行: ./02_create_schema.sh -t ${BENCHMARK_TYPE}${NC}"
    exit 1
fi

# 提取规模参数（不同基准测试使用不同的参数）
SCALEFACTOR=$(grep -oP '<scalefactor>\K[0-9]+' "${LOCAL_CONFIG}" || echo "10")
echo -e "${GREEN}✓ 配置加载成功${NC}"
echo -e "  - 基准测试: ${BENCHMARK_TYPE^^}"
echo -e "  - 规模因子: ${SCALEFACTOR}"

# 3. 执行数据加载
echo -e "\n${YELLOW}[步骤 3/3]${NC} 加载 ${BENCHMARK_TYPE} 测试数据..."
echo -e "${BLUE}正在批量插入数据（这可能需要较长时间，请耐心等待）...${NC}"
echo -e "${YELLOW}提示: 可以在另一个终端中查看容器日志:${NC}"
echo -e "  ${GREEN}docker logs -f ${CONTAINER_NAME}${NC}"
echo ""

# 记录开始时间
START_TIME=$(date +%s)

# 在容器内运行 BenchBase 的 load 命令
docker exec ${CONTAINER_NAME} bash -c "
    java -jar benchbase.jar \
        -b ${BENCHMARK_TYPE} \
        -c ${CONFIG_FILE} \
        --load=true
"

# 记录结束时间
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# 检查执行结果
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ 数据加载成功${NC}"
    echo -e "  - 耗时: ${MINUTES} 分 ${SECONDS} 秒"
else
    echo -e "\n${RED}✗ 数据加载失败${NC}"
    exit 1
fi

# 显示加载的数据统计
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  数据加载完成!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "基准测试: ${GREEN}${BENCHMARK_TYPE^^}${NC}"
echo -e "规模因子: ${GREEN}${SCALEFACTOR}${NC}"
echo -e "加载耗时: ${GREEN}${MINUTES} 分 ${SECONDS} 秒${NC}"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo -e "  运行: ${GREEN}./04_run_benchmark.sh -t ${BENCHMARK_TYPE}${NC} 执行基准测试"
echo ""
