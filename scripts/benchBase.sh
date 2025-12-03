#!/bin/bash
################################################################################
# BenchBase 测试脚本 - 一键运行完整测试流程
# 功能: 自动执行从环境初始化到结果分析的完整测试流程
# 用法: ./run_all.sh [-t benchmark_type]
################################################################################

set -e  # 遇到错误立即退出

# 颜色输出配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 默认配置
BENCHMARK_TYPE="tpcc"  # 默认使用 TPC-C

# 参数解析
while getopts "t:h" opt; do
    case $opt in
        t)
            BENCHMARK_TYPE="$OPTARG"
            ;;
        h)
            echo "用法: $0 [-t benchmark_type]"
            echo "选项:"
            echo "  -t    指定基准测试类型 (默认: tpcc)"
            echo "        可选: tpcc, smallbank, ycsb, tatp, tpch, wikipedia, chbenchmark 等"
            echo "  -h    显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0              # 运行 TPC-C 测试"
            echo "  $0 -t smallbank # 运行 SmallBank 测试"
            echo "  $0 -t ycsb      # 运行 YCSB 测试"
            echo "  $0 -t chbenchmark # 运行 CHBenchmark 混合测试"
            exit 0
            ;;
        \?)
            echo -e "${RED}无效选项: -$OPTARG${NC}" >&2
            exit 1
            ;;
    esac
done

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tools/benchbase" && pwd)"

echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}${NC}"
echo -e "${MAGENTA}        BenchBase 自动化测试流程 - ${BENCHMARK_TYPE^^}${NC}"
echo -e "${MAGENTA}        针对 openGauss 流复制集群${NC}"
echo -e "${MAGENTA}${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"

# 显示测试流程
echo -e "\n${CYAN}测试流程概览:${NC}"
echo -e "  ${GREEN}1${NC}. 启动 BenchBase 容器环境"
echo -e "  ${GREEN}2${NC}. 创建 ${BENCHMARK_TYPE^^} 数据库 Schema"
echo -e "  ${GREEN}3${NC}. 加载测试数据"
echo -e "  ${GREEN}4${NC}. 执行基准测试"
echo -e "  ${GREEN}5${NC}. 分析测试结果"
echo ""

# 读取配置参数
CONFIG_FILE="${SCRIPT_DIR}/config/${BENCHMARK_TYPE}_config.xml"
if [ -f "$CONFIG_FILE" ]; then
    SCALEFACTOR=$(grep -oP '<scalefactor>\K[0-9]+' "$CONFIG_FILE" 2>/dev/null || echo "10")
    TERMINALS=$(grep -oP '<terminals>\K[0-9]+' "$CONFIG_FILE" 2>/dev/null || echo "16")
    DURATION=$(grep -oP '<time>\K[0-9]+' "$CONFIG_FILE" 2>/dev/null || echo "60")
    
    echo -e "${CYAN}测试配置:${NC}"
    echo -e "  基准测试: ${BENCHMARK_TYPE^^}"
    echo -e "  规模因子: ${SCALEFACTOR}"
    echo -e "  并发终端: ${TERMINALS}"
    echo -e "  测试时长: ${DURATION} 秒"
else
    echo -e "${YELLOW}⚠ 配置文件不存在: ${CONFIG_FILE}${NC}"
    echo -e "${YELLOW}提示: 请先从 config/postgres/sample_${BENCHMARK_TYPE}_config.xml 复制并修改${NC}"
    exit 1
fi

# 记录总开始时间
TOTAL_START=$(date +%s)

echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}开始执行自动化测试流程 ($(date '+%Y-%m-%d %H:%M:%S'))${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

# ============================================================================
# 步骤 1: 检查并启动容器
# ============================================================================
echo -e "${MAGENTA}[阶段 1/5] 检查 BenchBase 容器状态${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

CONTAINER_NAME="benchbase-client"
STEP_START=$(date +%s)

# 检查容器是否存在
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    # 容器存在，检查是否运行
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${GREEN}✓ 容器正在运行${NC}"
    else
        # 容器已停止，启动它
        echo -e "${YELLOW}→ 容器已停止，正在启动...${NC}"
        docker start ${CONTAINER_NAME}
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ 容器已启动${NC}"
        else
            echo -e "${RED}✗ 容器启动失败${NC}"
            exit 1
        fi
    fi
else
    # 容器不存在，创建新容器
    echo -e "${YELLOW}→ 容器不存在，正在创建...${NC}"
    if [ -f "${SCRIPT_DIR}/01_start_benchbase.sh" ]; then
        bash "${SCRIPT_DIR}/01_start_benchbase.sh"
    else
        echo -e "${RED}错误: 脚本不存在: 01_start_benchbase.sh${NC}"
        exit 1
    fi
fi

STEP_END=$(date +%s)
STEP_DURATION=$((STEP_END - STEP_START))
echo -e "${GREEN}✓ 阶段 1 完成 (耗时: ${STEP_DURATION} 秒)${NC}\n"
sleep 2

# ============================================================================
# 步骤 2: 创建 Schema
# ============================================================================
echo -e "${MAGENTA}[阶段 2/5] 创建数据库 Schema${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
STEP_START=$(date +%s)

# CHBenchmark 需要特殊的两阶段初始化（TPC-C + TPC-H）
if [ "${BENCHMARK_TYPE}" = "chbenchmark" ]; then
    if [ -f "${SCRIPT_DIR}/02_create_schema_chbenchmark.sh" ]; then
        bash "${SCRIPT_DIR}/02_create_schema_chbenchmark.sh"
    else
        echo -e "${YELLOW}⚠ CHBenchmark 专用脚本不存在，使用标准流程${NC}"
        bash "${SCRIPT_DIR}/02_create_schema.sh" -t "${BENCHMARK_TYPE}"
    fi
else
    if [ -f "${SCRIPT_DIR}/02_create_schema.sh" ]; then
        bash "${SCRIPT_DIR}/02_create_schema.sh" -t "${BENCHMARK_TYPE}"
    else
        echo -e "${RED}错误: 脚本不存在: 02_create_schema.sh${NC}"
        exit 1
    fi
fi

STEP_END=$(date +%s)
STEP_DURATION=$((STEP_END - STEP_START))
echo -e "${GREEN}✓ 阶段 2 完成 (耗时: ${STEP_DURATION} 秒)${NC}\n"
sleep 2

# ============================================================================
# 步骤 3: 加载数据
# ============================================================================
echo -e "${MAGENTA}[阶段 3/5] 加载测试数据${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
STEP_START=$(date +%s)

# CHBenchmark 需要先加载 TPC-C 数据，再加载 TPC-H 数据
if [ "${BENCHMARK_TYPE}" = "chbenchmark" ]; then
    echo -e "${CYAN}→ CHBenchmark 需要分两步加载数据...${NC}"
    echo -e "\n${BLUE}[3.1] 加载 TPC-C 数据...${NC}"
    if [ -f "${SCRIPT_DIR}/03_load_data.sh" ]; then
        bash "${SCRIPT_DIR}/03_load_data.sh" -t "tpcc"
    else
        echo -e "${RED}错误: 脚本不存在: 03_load_data.sh${NC}"
        exit 1
    fi
    
    echo -e "\n${BLUE}[3.2] 加载 TPC-H 数据...${NC}"
    if [ -f "${SCRIPT_DIR}/03_load_data.sh" ]; then
        bash "${SCRIPT_DIR}/03_load_data.sh" -t "chbenchmark"
    else
        echo -e "${RED}错误: 脚本不存在: 03_load_data.sh${NC}"
        exit 1
    fi
else
    if [ -f "${SCRIPT_DIR}/03_load_data.sh" ]; then
        bash "${SCRIPT_DIR}/03_load_data.sh" -t "${BENCHMARK_TYPE}"
    else
        echo -e "${RED}错误: 脚本不存在: 03_load_data.sh${NC}"
        exit 1
    fi
fi

STEP_END=$(date +%s)
STEP_DURATION=$((STEP_END - STEP_START))
echo -e "${GREEN}✓ 阶段 3 完成 (耗时: ${STEP_DURATION} 秒)${NC}\n"
sleep 2

# ============================================================================
# 步骤 4: 执行测试
# ============================================================================
echo -e "${MAGENTA}[阶段 4/5] 执行基准测试${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
STEP_START=$(date +%s)

if [ -f "${SCRIPT_DIR}/04_run_benchmark.sh" ]; then
    bash "${SCRIPT_DIR}/04_run_benchmark.sh" -t "${BENCHMARK_TYPE}"
else
    echo -e "${RED}错误: 脚本不存在: 04_run_benchmark.sh${NC}"
    exit 1
fi

STEP_END=$(date +%s)
STEP_DURATION=$((STEP_END - STEP_START))
echo -e "${GREEN}✓ 阶段 4 完成 (耗时: ${STEP_DURATION} 秒)${NC}\n"
sleep 2

# ============================================================================
# 步骤 5: 分析结果
# ============================================================================
echo -e "${MAGENTA}[阶段 5/5] 分析测试结果${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
STEP_START=$(date +%s)

if [ -f "${SCRIPT_DIR}/05_analyze_results.sh" ]; then
    bash "${SCRIPT_DIR}/05_analyze_results.sh" -t "${BENCHMARK_TYPE}"
else
    echo -e "${RED}错误: 脚本不存在: 05_analyze_results.sh${NC}"
    exit 1
fi

STEP_END=$(date +%s)
STEP_DURATION=$((STEP_END - STEP_START))
echo -e "${GREEN}✓ 阶段 5 完成 (耗时: ${STEP_DURATION} 秒)${NC}\n"

# ============================================================================
# 显示最终摘要
# ============================================================================
TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))
TOTAL_MINUTES=$((TOTAL_DURATION / 60))
TOTAL_SECONDS=$((TOTAL_DURATION % 60))

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                            ║${NC}"
echo -e "${MAGENTA}║              🎉 完整测试流程执行完成! 🎉                  ║${NC}"
echo -e "${MAGENTA}║                                                            ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}执行摘要:${NC}"
echo -e "  开始时间戳: ${TOTAL_START}"
echo -e "  结束时间戳: ${TOTAL_END}"
echo -e "  总耗时: ${GREEN}${TOTAL_MINUTES} 分 ${TOTAL_SECONDS} 秒${NC}"
echo ""
echo -e "${CYAN}下一步操作:${NC}"
echo -e "  ${GREEN}1${NC}. 查看详细报告: ${GREEN}cat ${SCRIPT_DIR}/results/latest_report.txt${NC}"
echo -e "  ${GREEN}2${NC}. 清理测试环境: ${GREEN}./cleanup.sh${NC}"
echo -e "  ${GREEN}3${NC}. 调整配置重测: ${GREEN}vi config/tpcc_config.xml && ./run_all.sh${NC}"
echo ""
echo -e "${YELLOW}提示: 测试结果已保存在 ${SCRIPT_DIR}/results/ 目录${NC}"
echo ""
