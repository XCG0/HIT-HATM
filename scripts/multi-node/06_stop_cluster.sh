#!/bin/bash
# openGauss 多节点集群 - 停止脚本
# 在宿主机上运行此脚本

set -e

echo "=== openGauss 集群停止 ==="
echo ""

# 自动发现所有 opengauss 容器
echo "正在发现集群节点..."
STANDBY_CONTAINERS=()
STANDBY_NAMES=()

# 检查主节点
PRIMARY_EXISTS=false
if docker ps -q -f name=opengauss-primary | grep -q .; then
    PRIMARY_EXISTS=true
    echo "  ✓ 发现主节点: opengauss-primary"
fi

# 自动发现所有备节点
for i in {1..10}; do
    container_name="opengauss-standby$i"
    if docker ps -q -f name=$container_name | grep -q .; then
        STANDBY_CONTAINERS+=("$container_name")
        STANDBY_NAMES+=("standby$i")
        echo "  ✓ 发现备节点$i: $container_name"
    fi
done

STANDBY_COUNT=${#STANDBY_CONTAINERS[@]}

if ! $PRIMARY_EXISTS && [ $STANDBY_COUNT -eq 0 ]; then
    echo "  没有发现任何运行中的集群节点"
    echo ""
    echo "=== 集群已停止 ==="
    exit 0
fi

if [ $STANDBY_COUNT -eq 0 ]; then
    echo "  没有发现备节点（单节点模式）"
else
    echo ""
    echo "集群配置: 1 主节点 + $STANDBY_COUNT 备节点"
fi
echo ""

# 按顺序停止：先备节点，后主节点
if [ $STANDBY_COUNT -gt 0 ]; then
    echo "停止备节点..."
    # 反向停止备节点（从最后一个到第一个）
    for ((i=${#STANDBY_CONTAINERS[@]}-1; i>=0; i--)); do
        container="${STANDBY_CONTAINERS[$i]}"
        standby_name="${STANDBY_NAMES[$i]}"
        
        echo "  停止 $standby_name..."
        docker exec $container su - omm -c "
            gs_ctl stop -D /home/omm/data
        " 2>/dev/null || echo "    $standby_name 已停止或未运行"
        
        echo "    ✓ $standby_name 停止完成"
    done
    echo ""
fi

if $PRIMARY_EXISTS; then
    echo "停止主节点..."
    docker exec opengauss-primary su - omm -c "
        gs_ctl stop -D /home/omm/data
    " 2>/dev/null || echo "  主节点已停止或未运行"
    
    echo "  ✓ 主节点停止完成"
    echo ""
fi

echo "=== 集群停止完成 ==="
