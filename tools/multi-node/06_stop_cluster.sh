#!/bin/bash
# openGauss 多节点集群 - 停止脚本
set -e

echo "[1/3] 发现集群节点"
STANDBY_CONTAINERS=()
STANDBY_NAMES=()

# 检查主节点
PRIMARY_EXISTS=false
if docker ps -q -f name=opengauss-primary | grep -q .; then
    PRIMARY_EXISTS=true
    echo "  ✓ 主节点: opengauss-primary"
fi

# 自动发现所有备节点
for i in {1..10}; do
    container_name="opengauss-standby$i"
    if docker ps -q -f name=$container_name | grep -q .; then
        STANDBY_CONTAINERS+=("$container_name")
        STANDBY_NAMES+=("standby$i")
        echo "  ✓ 备节点$i: $container_name"
    fi
done

STANDBY_COUNT=${#STANDBY_CONTAINERS[@]}

if ! $PRIMARY_EXISTS && [ $STANDBY_COUNT -eq 0 ]; then
    echo "  没有发现任何运行中的集群节点"
    echo ""
    echo "✓ 集群已停止"
    exit 0
fi

echo "  发现: 1主+${STANDBY_COUNT}备"

# 按顺序停止：先备节点，后主节点
if [ $STANDBY_COUNT -gt 0 ]; then
    echo "[2/3] 停止备节点数据库 (${STANDBY_COUNT}个)"
    # 反向停止备节点（从最后一个到第一个）
    for ((i=${#STANDBY_CONTAINERS[@]}-1; i>=0; i--)); do
        container="${STANDBY_CONTAINERS[$i]}"
        standby_name="${STANDBY_NAMES[$i]}"
        
        printf "  [%d/%d] %s ... " $((STANDBY_COUNT-i)) $STANDBY_COUNT $standby_name
        
        if docker exec $container su - omm -c "gs_ctl stop -D /home/omm/data -m fast" > /dev/null 2>&1; then
            echo "✓"
        else
            echo "已停止 ✓"
        fi
    done
else
    echo "[2/3] 跳过备节点停止 (无备节点)"
fi

if $PRIMARY_EXISTS; then
    echo "[3/3] 停止主节点数据库"
    
    if docker exec opengauss-primary su - omm -c "gs_ctl stop -D /home/omm/data -m fast" > /dev/null 2>&1; then
        echo "  ✓ 主节点停止完成"
    else
        echo "  ✓ 主节点已停止"
    fi
fi

echo "✓ 集群停止完成"
