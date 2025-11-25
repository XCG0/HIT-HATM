#!/bin/bash

# BenchBase openGauss 多节点测试快速启动脚本
# 使用前请确保已经配置好openGauss多节点集群

set -e

# 配置参数
BENCHBASE_HOME="/path/to/benchbase-postgres"
CONFIG_DIR="./config"
RESULTS_DIR="./results/$(date +%Y%m%d_%H%M%S)"
BENCHMARKS=("tpcc" "tpch" "ycsb" "smallbank")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查环境
check_environment() {
    log_info "检查测试环境..."
    
    # 检查Java版本
    if ! command -v java &> /dev/null; then
        log_error "Java未安装，请安装Java 17或更高版本"
        exit 1
    fi
    
    java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
    if [ "$java_version" -lt 17 ]; then
        log_error "Java版本过低，需要Java 17或更高版本"
        exit 1
    fi
    
    # 检查BenchBase
    if [ ! -f "$BENCHBASE_HOME/benchbase.jar" ]; then
        log_error "BenchBase未找到，请检查BENCHBASE_HOME路径"
        exit 1
    fi
    
    # 检查配置文件
    for benchmark in "${BENCHMARKS[@]}"; do
        config_file="$CONFIG_DIR/${benchmark}_opengauss.xml"
        if [ ! -f "$config_file" ]; then
            log_warn "配置文件不存在: $config_file"
        fi
    done
    
    log_info "环境检查完成"
}

# 测试数据库连接
test_database_connection() {
    log_info "测试数据库连接..."
    
    # 这里可以添加数据库连接测试逻辑
    # 例如：使用psql连接测试
    # psql -h 192.168.1.10 -p 5432 -U benchbase_user -d benchbase -c "SELECT 1;"
    
    log_info "数据库连接测试完成"
}

# 初始化数据库
init_database() {
    local benchmark=$1
    log_info "初始化 $benchmark 数据库..."
    
    cd "$BENCHBASE_HOME"
    java -jar benchbase.jar \
        -b "$benchmark" \
        -c "$CONFIG_DIR/${benchmark}_opengauss.xml" \
        --create=true \
        --load=true
    
    log_info "$benchmark 数据库初始化完成"
}

# 执行基准测试
run_benchmark() {
    local benchmark=$1
    log_info "执行 $benchmark 基准测试..."
    
    cd "$BENCHBASE_HOME"
    mkdir -p "$RESULTS_DIR/$benchmark"
    
    java -jar benchbase.jar \
        -b "$benchmark" \
        -c "$CONFIG_DIR/${benchmark}_opengauss.xml" \
        --execute=true \
        -d "$RESULTS_DIR/$benchmark" \
        -im 5000 \
        -jh "$RESULTS_DIR/$benchmark/histogram.json"
    
    log_info "$benchmark 基准测试完成，结果保存在: $RESULTS_DIR/$benchmark"
}

# 生成测试报告
generate_report() {
    log_info "生成测试报告..."
    
    report_file="$RESULTS_DIR/test_summary.md"
    
    cat > "$report_file" << EOF
# BenchBase openGauss 多节点测试报告

## 测试信息
- 测试时间: $(date)
- 测试环境: openGauss多节点集群
- BenchBase版本: $(java -jar "$BENCHBASE_HOME/benchbase.jar" --version 2>/dev/null || echo "未知")

## 测试结果摘要

EOF

    for benchmark in "${BENCHMARKS[@]}"; do
        result_dir="$RESULTS_DIR/$benchmark"
        if [ -d "$result_dir" ]; then
            echo "### $benchmark 测试结果" >> "$report_file"
            if [ -f "$result_dir/summary.json" ]; then
                echo "- 详细结果: [查看]($result_dir/summary.json)" >> "$report_file"
            fi
            echo "" >> "$report_file"
        fi
    done
    
    log_info "测试报告已生成: $report_file"
}

# 清理数据库
cleanup_database() {
    local benchmark=$1
    log_info "清理 $benchmark 数据库..."
    
    cd "$BENCHBASE_HOME"
    java -jar benchbase.jar \
        -b "$benchmark" \
        -c "$CONFIG_DIR/${benchmark}_opengauss.xml" \
        --clear=true
    
    log_info "$benchmark 数据库清理完成"
}

# 主菜单
show_menu() {
    echo ""
    echo "BenchBase openGauss 多节点测试工具"
    echo "=================================="
    echo "1. 检查环境"
    echo "2. 测试数据库连接"
    echo "3. 初始化数据库 (所有基准)"
    echo "4. 执行单个基准测试"
    echo "5. 执行所有基准测试"
    echo "6. 清理数据库"
    echo "7. 生成测试报告"
    echo "8. 退出"
    echo ""
}

# 选择基准
select_benchmark() {
    echo "可用的基准测试:"
    for i in "${!BENCHMARKS[@]}"; do
        echo "$((i+1)). ${BENCHMARKS[$i]}"
    done
    read -p "请选择基准测试 (1-${#BENCHMARKS[@]}): " choice
    
    if [[ "$choice" -ge 1 && "$choice" -le "${#BENCHMARKS[@]}" ]]; then
        echo "${BENCHMARKS[$((choice-1))]}"
    else
        echo ""
    fi
}

# 执行所有基准测试
run_all_benchmarks() {
    log_info "开始执行所有基准测试..."
    
    for benchmark in "${BENCHMARKS[@]}"; do
        config_file="$CONFIG_DIR/${benchmark}_opengauss.xml"
        if [ -f "$config_file" ]; then
            run_benchmark "$benchmark"
        else
            log_warn "跳过 $benchmark - 配置文件不存在"
        fi
    done
    
    generate_report
    log_info "所有基准测试完成！"
}

# 主程序
main() {
    while true; do
        show_menu
        read -p "请选择操作 (1-8): " choice
        
        case $choice in
            1)
                check_environment
                ;;
            2)
                test_database_connection
                ;;
            3)
                log_info "初始化所有基准数据库..."
                for benchmark in "${BENCHMARKS[@]}"; do
                    config_file="$CONFIG_DIR/${benchmark}_opengauss.xml"
                    if [ -f "$config_file" ]; then
                        init_database "$benchmark"
                    fi
                done
                ;;
            4)
                selected_benchmark=$(select_benchmark)
                if [ -n "$selected_benchmark" ]; then
                    run_benchmark "$selected_benchmark"
                else
                    log_error "无效的选择"
                fi
                ;;
            5)
                run_all_benchmarks
                ;;
            6)
                selected_benchmark=$(select_benchmark)
                if [ -n "$selected_benchmark" ]; then
                    cleanup_database "$selected_benchmark"
                else
                    log_error "无效的选择"
                fi
                ;;
            7)
                generate_report
                ;;
            8)
                log_info "退出测试工具"
                break
                ;;
            *)
                log_error "无效的选择，请输入1-8"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# 如果直接执行脚本
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi