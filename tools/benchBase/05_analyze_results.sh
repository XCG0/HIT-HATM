#!/bin/bash
################################################################################
# BenchBase 测试脚本 - 步骤5: 分析测试结果
# 功能: 解析并展示基准测试性能指标
# 用法: ./05_analyze_results.sh [-t benchmark_type] [result_file]
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
RESULTS_DIR="${SCRIPT_DIR}/results"
PYTHON_SCRIPT="${SCRIPT_DIR}/analyze_results.py"
BENCHMARK_TYPE=""
RESULT_FILE=""

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

# 移除已处理的选项
shift $((OPTIND-1))

# 获取剩余的参数（结果文件路径）
if [ $# -gt 0 ]; then
    RESULT_FILE="$1"
fi

echo -e "${BLUE}========================================${NC}"
if [ -n "$BENCHMARK_TYPE" ]; then
    echo -e "${BLUE}  BenchBase 结果分析 - ${BENCHMARK_TYPE^^}${NC}"
else
    echo -e "${BLUE}  BenchBase 结果分析${NC}"
fi
echo -e "${BLUE}========================================${NC}"

# 1. 检查 Python 分析脚本
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo -e "${RED}错误: 找不到 Python 分析脚本: $PYTHON_SCRIPT${NC}"
    exit 1
fi

# 2. 检查 Python 是否可用
USE_PYTHON_ANALYSIS=true
PYTHON_CMD=""

if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    echo -e "${YELLOW}警告: 未安装 Python，将直接打印 JSON 结果${NC}"
    USE_PYTHON_ANALYSIS=false
else
    # 3. 确定 Python 命令（优先使用 python，然后 python3）
    if command -v python >/dev/null 2>&1 && python --version >/dev/null 2>&1; then
        PYTHON_CMD="python"
    elif command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    else
        echo -e "${YELLOW}警告: Python 命令无法正常工作，将直接打印 JSON 结果${NC}"
        USE_PYTHON_ANALYSIS=false
    fi
    
    # 4. 检查 Python 版本（需要 3.6+，推荐 3.7+）
    if [ "$USE_PYTHON_ANALYSIS" = true ]; then
        # 使用更兼容的版本检测方法（不使用 f-string）
        PYTHON_VERSION=$($PYTHON_CMD -c 'import sys; print("{}.{}".format(sys.version_info.major, sys.version_info.minor))' 2>/dev/null || echo "0.0")
        MAJOR_VERSION=$(echo $PYTHON_VERSION | cut -d'.' -f1)
        MINOR_VERSION=$(echo $PYTHON_VERSION | cut -d'.' -f2)
        
        if [ "$MAJOR_VERSION" -lt 3 ] || ([ "$MAJOR_VERSION" -eq 3 ] && [ "$MINOR_VERSION" -lt 6 ]); then
            echo -e "${YELLOW}警告: Python 版本 $PYTHON_VERSION 过低（需要 3.6+），将直接打印 JSON 结果${NC}"
            USE_PYTHON_ANALYSIS=false
        else
            echo -e "${GREEN}✓ 检测到 Python $PYTHON_VERSION (使用 $PYTHON_CMD)${NC}"
        fi
    fi
fi

# 5. 查找结果文件
JSON_FILE=""
if [ -z "$RESULT_FILE" ]; then
    echo -e "\n${YELLOW}[查找]${NC} 搜索最新的测试结果..."
    
    if [ -n "$BENCHMARK_TYPE" ]; then
        # 查找指定类型的最新结果（包括子文件夹）
        JSON_FILE=$(find "${RESULTS_DIR}" -name "${BENCHMARK_TYPE}_*.summary.json" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
        
        if [ -z "$JSON_FILE" ]; then
            echo -e "${RED}错误: 未找到 ${BENCHMARK_TYPE} 的测试结果文件${NC}"
            echo -e "${YELLOW}提示: 请先运行 ./04_run_benchmark.sh -t ${BENCHMARK_TYPE}${NC}"
            exit 1
        fi
    else
        # 查找任意类型的最新结果（包括子文件夹）
        JSON_FILE=$(find "${RESULTS_DIR}" -name "*.summary.json" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
        
        if [ -z "$JSON_FILE" ]; then
            echo -e "${RED}错误: 未找到测试结果文件${NC}"
            echo -e "${YELLOW}提示: 请先运行基准测试${NC}"
            exit 1
        fi
    fi
    
    # 提取测试类型和时间
    BASENAME=$(basename "$JSON_FILE" .summary.json)
    echo -e "${GREEN}✓ 找到结果: ${BASENAME}${NC}"
else
    JSON_FILE="$RESULT_FILE"
    if [ ! -f "$JSON_FILE" ]; then
        echo -e "${RED}错误: 文件不存在: $JSON_FILE${NC}"
        exit 1
    fi
fi

# 6. 组织结果文件到子文件夹
echo -e "\n${YELLOW}[整理]${NC} 组织测试结果文件..."
BASENAME=$(basename "$JSON_FILE" .summary.json)
RESULT_SUBFOLDER="${RESULTS_DIR}/${BASENAME}"

# 创建子文件夹
mkdir -p "$RESULT_SUBFOLDER"

# 检查 JSON 文件是否已在子文件夹中
if [ "$(dirname "$JSON_FILE")" != "$RESULT_SUBFOLDER" ]; then
    # 查找所有相关文件并移动到子文件夹
    echo -e "  → 移动文件到: ${BASENAME}/"
    for file in "${RESULTS_DIR}/${BASENAME}."*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            mv "$file" "${RESULT_SUBFOLDER}/${filename}" 2>/dev/null || true
        fi
    done
    # 更新 JSON_FILE 路径
    JSON_FILE="${RESULT_SUBFOLDER}/$(basename "$JSON_FILE")"
    echo -e "${GREEN}✓ 文件已整理${NC}"
else
    echo -e "${GREEN}✓ 文件已在子文件夹中${NC}"
fi

# 7. 执行分析或直接打印 JSON
if [ "$USE_PYTHON_ANALYSIS" = true ]; then
    # 使用 Python 分析脚本
    echo -e "\n${YELLOW}[分析中]${NC} 使用 $PYTHON_CMD 解析测试结果...\n"
    
    # 切换到脚本目录以避免路径问题
    cd "$SCRIPT_DIR"
    
    # 计算相对路径（从 SCRIPT_DIR 到 JSON_FILE）
    RELATIVE_JSON_PATH=$(realpath --relative-to="$SCRIPT_DIR" "$JSON_FILE" 2>/dev/null || echo "$JSON_FILE")
    
    # 如果 realpath 失败，尝试手动构建相对路径
    if [ "$RELATIVE_JSON_PATH" = "$JSON_FILE" ] && [[ "$JSON_FILE" == "${RESULTS_DIR}"* ]]; then
        RELATIVE_JSON_PATH="results/${JSON_FILE#${RESULTS_DIR}/}"
    fi
    
    # 传递相对路径给 Python
    $PYTHON_CMD "$(basename "$PYTHON_SCRIPT")" "$RELATIVE_JSON_PATH"
    
    # 检查执行结果
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 分析完成${NC}"
        
        # 获取报告路径
        REPORT_FILE="${RESULT_SUBFOLDER}/final_report.txt"
        
        if [ -f "$REPORT_FILE" ]; then
            echo -e "${GREEN}✓ 报告已保存: ${REPORT_FILE}${NC}"
        fi
    else
        echo -e "${RED}✗ 分析失败${NC}"
        exit 1
    fi
    
    # 提示其他操作
    echo -e "\n${YELLOW}其他操作:${NC}"
    if [ -f "$REPORT_FILE" ]; then
        echo -e "  文本报告:         ${GREEN}${REPORT_FILE}${NC}"
    fi
    echo -e "  查看所有结果:     ${GREEN}ls -lh ${RESULTS_DIR}/${NC}"
    echo -e "  查看测试文件夹:   ${GREEN}ls -lh ${RESULT_SUBFOLDER}${NC}"
else
    # 直接打印 JSON 文件内容
    echo -e "\n${YELLOW}[结果]${NC} 直接打印 JSON 文件内容:\n"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  文件: $(basename "$JSON_FILE")${NC}"
    echo -e "${BLUE}========================================${NC}\n"
    
    if command -v jq >/dev/null 2>&1; then
        # 如果有 jq，使用格式化输出
        cat "$JSON_FILE" | jq '.'
    else
        # 否则直接输出
        cat "$JSON_FILE"
    fi
    
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${GREEN}✓ JSON 文件路径: ${JSON_FILE}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    echo -e "\n${YELLOW}提示:${NC}"
    echo -e "  安装 Python 3.7+ 可使用增强分析功能"
fi
echo ""
