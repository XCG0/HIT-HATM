#!/bin/bash
# openGauss 多节点集群 - 一键自动部署脚本
# 用法: ./multi-node.sh [-n 节点数] [-m 复制模式] [-y 所有步骤自动确认]

set -e

# ==================== 配置参数 ====================
DEFAULT_STANDBY_COUNT=2
DEFAULT_REPLICATION_MODE="ANY1"
AUTO_CONFIRM=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==================== 帮助信息 ====================
show_help() {
    cat << EOF
openGauss 多节点集群一键部署脚本

用法: $0 [选项]

选项:
    -n NUMBER   备节点数量 (1-10)，默认: ${DEFAULT_STANDBY_COUNT}
    -m MODE     复制模式，默认: ${DEFAULT_REPLICATION_MODE}
    -y          所有步骤自动确认，不提示
    -h          显示帮助

示例:
    $0 -m SYNC           # 1主2备，SYNC模式，每步确认
    $0 -m ASYNC -y       # 1主2备，ASYNC模式，自动执行
    $0 -n 2 -m ANY1      # 1主2备，ANY1模式，每步确认（默认）
    $0 -n 4 -m ANY2 -y   # 1主4备，ANY2模式，自动执行
    $0 -n 3 -m FIRST2    # 1主3备，FIRST2模式，每步确认

EOF
}

# ==================== 用户确认函数 ====================
user_confirm() {
    local step_num=$1
    local step_name=$2
    local step_desc=$3
    
    if [ "$AUTO_CONFIRM" = true ]; then
        # 自动模式：不显示额外信息，直接返回继续
        return 0
    fi
    
    # 手动模式：显示确认提示
    echo -e "请选择操作:"
    echo -e "  ${GREEN}[C] 继续执行${NC} (默认)"
    echo -e "  ${YELLOW}[S] 跳过此步骤${NC}"
    echo -e "  ${RED}[Q] 退出部署${NC}"
    echo ""
    
    while true; do
        read -p "请输入选择 [C/s/q]: " -r choice
        case "${choice,,}" in
            ""|c) return 0 ;;  # 继续
            s) return 1 ;;     # 跳过
            q) 
                echo -e "${RED}✗ 用户取消部署${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请输入 C、S 或 Q${NC}"
                ;;
        esac
    done
}

# ==================== 执行脚本函数 ====================
execute_script() {
    local step_num=$1
    local script_name=$2
    local step_desc=$3
    shift 3
    local args="$@"
    local script_path="${SCRIPT_DIR}/multi-node/${script_name}"
    
    # 显示步骤信息（自动和手动模式都显示）
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}步骤 ${step_num}: ${script_name}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  描述: ${step_desc}"
    echo ""
    
    # 用户确认
    if ! user_confirm "$step_num" "$script_name" "$step_desc"; then
        echo -e "${YELLOW}⊘ 跳过步骤 ${step_num}: ${script_name}${NC}"
        return 0  # 返回成功，继续下一步
    fi
    
    # 检查脚本是否存在
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}✗ 错误: 脚本不存在 $script_path${NC}"
        return 1
    fi
    
    # 执行脚本
    echo -e "${BLUE}正在执行...${NC}"
    
    # 直接执行脚本并显示输出
    if bash "$script_path" $args; then
        echo -e "${GREEN}✓ 步骤 ${step_num} 完成${NC}"
        return 0
    else
        echo -e "${RED}✗ 步骤 ${step_num} 失败${NC}"
        return 1
    fi
}

# ==================== 主程序 ====================
main() {
    # 解析命令行参数
    local STANDBY_COUNT=$DEFAULT_STANDBY_COUNT
    local REPLICATION_MODE=$DEFAULT_REPLICATION_MODE
    
    while getopts "n:m:yh" opt; do
        case $opt in
            n) STANDBY_COUNT=$OPTARG ;;
            m) REPLICATION_MODE=$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]') ;;
            y) AUTO_CONFIRM=true ;;
            h) show_help; exit 0 ;;
            \?) echo "错误: 无效选项 -$OPTARG"; show_help; exit 1 ;;
        esac
    done
    
    # 显示配置
    clear
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                ║${NC}"
    echo -e "${BLUE}║      openGauss 多节点集群自动部署工具          ║${NC}"
    echo -e "${BLUE}║                                                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  📦 集群规模: ${GREEN}1主 + ${STANDBY_COUNT}备${NC}"
    echo -e "  🔄 复制模式: ${GREEN}${REPLICATION_MODE}${NC}"
    echo -e "  ⚡ 确认模式: $([ "$AUTO_CONFIRM" = true ] && echo "${GREEN}自动确认${NC}" || echo "${YELLOW}手动确认${NC}")"
    echo ""
    
    # 确认开始
    if [ "$AUTO_CONFIRM" = false ]; then
        read -p "$(echo -e "${YELLOW}按 Enter 开始部署，Ctrl+C 取消...${NC}")" -r
    else
        echo -e "${GREEN}[自动模式] 开始部署...${NC}"
    fi
    
    START_TIME=$(date +%s)
    
    # 步骤1: 创建容器
    if ! execute_script 1 "01_create_containers.sh" "创建 Docker 容器和网络配置" "-n $STANDBY_COUNT"; then
        echo -e "${RED}✗ 部署失败: 容器创建失败${NC}"
        exit 1
    fi
    
    # 等待容器初始化完成并检查 Git 仓库来源
    echo ""
    echo "  等待容器初始化..."
    
    # 等待 init-container.sh 执行完成（检查 .git 目录和代码文件）
    for i in {1..30}; do
        if docker exec opengauss-primary bash -c 'test -f /home/README.md && test -d /home/.git' 2>/dev/null; then
            break
        fi
        sleep 1
    done
    sleep 2  # 额外等待确保 git remote 设置完成
    
    # 从 primary 节点检查仓库来源
    REPO_URL=$(docker exec opengauss-primary bash -c 'cd /home && git remote get-url origin 2>/dev/null || echo "unknown"')
    
    if [[ "$REPO_URL" == *"github.com"* ]]; then
        echo -e "  ✓ 代码来源: ${GREEN}GitHub${NC} ($REPO_URL)"
        echo -e "  📡 网络状态: 容器内可访问 GitHub"
    elif [[ "$REPO_URL" == *"gitee.com"* ]]; then
        echo -e "  ✓ 代码来源: ${YELLOW}Gitee 镜像${NC} ($REPO_URL)"
        echo -e "  📡 网络状态: 容器内不可访问 GitHub，已使用国内镜像"
    elif [[ "$REPO_URL" == "unknown" ]]; then
        echo -e "  ⚠️  代码来源: ${YELLOW}未检测到 Git 仓库${NC}"
    else
        echo -e "  ✓ 代码来源: ${REPO_URL}"
    fi
    echo ""
    
    # 步骤2: 配置SSH
    if ! execute_script 2 "02_setup_ssh.sh" "配置节点间 SSH 免密登录" ; then
        echo -e "${YELLOW}⚠ SSH配置失败，但继续部署${NC}"
    fi
    
    # 步骤3: 初始化集群
    if ! execute_script 3 "03_init_cluster.sh" "初始化数据库集群和主备复制" "-m $REPLICATION_MODE"; then
        echo -e "${RED}✗ 部署失败: 集群初始化失败${NC}"
        exit 1
    fi
    
    # 步骤4: 启动集群
    if ! execute_script 4 "04_start_cluster.sh" "启动所有数据库节点" ; then
        echo -e "${RED}✗ 部署失败: 集群启动失败${NC}"
        exit 1
    fi
    
    # 步骤5: 验证集群
    if ! execute_script 5 "05_verify_cluster.sh" "验证集群状态和复制功能" ; then
        echo -e "${RED}✗ 部署失败: 集群验证失败${NC}"
        exit 1
    fi
    
    # 完成
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 集群部署成功！${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  ⏱️  部署耗时: ${DURATION} 秒"
    echo "  🏗️  集群规模: 1 主节点 + ${STANDBY_COUNT} 备节点"
    echo "  🔄 复制模式: ${REPLICATION_MODE}"
    
    # 显示仓库来源
    if [[ "$REPO_URL" == *"github.com"* ]]; then
        echo "  📦 代码来源: GitHub ($REPO_URL)"
    elif [[ "$REPO_URL" == *"gitee.com"* ]]; then
        echo "  📦 代码来源: Gitee 镜像 ($REPO_URL)"
    fi
    
    echo ""
    echo -e "${BLUE}快速操作命令:${NC}"
    echo ""
    echo "  # 查看复制状态"
    echo "  docker exec opengauss-primary su - omm -c \"gsql -d postgres -c 'SELECT application_name, sync_state FROM pg_stat_replication;'\""
    echo ""
    echo "  # 连接数据库"
    echo "  docker exec -it opengauss-primary su - omm -c 'gsql -d postgres'"
    echo ""
    echo "  # 查看主节点状态"
    echo "  docker exec opengauss-primary su - omm -c 'gs_ctl query -D /home/omm/data'"
    echo ""
}

# ==================== 错误处理 ====================
trap 'echo -e "\n${RED}✗ 部署被中断${NC}"; exit 1' INT TERM

# 执行主程序
main "$@"
