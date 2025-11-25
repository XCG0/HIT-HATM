#!/bin/bash
# openGauss 多节点集群 - 启动脚本（简化版）
set -e

echo "[1/3] 发现集群节点"

# 检查主节点
if ! docker ps -q -f name=opengauss-primary | grep -q .; then
    echo "错误: 未找到主节点"
    exit 1
fi

# 发现备节点
STANDBY_CONTAINERS=()
for i in {1..10}; do
    if docker ps -q -f name=opengauss-standby$i | grep -q .; then
        STANDBY_CONTAINERS+=("opengauss-standby$i")
    fi
done

STANDBY_COUNT=${#STANDBY_CONTAINERS[@]}
echo "  发现: 1主+${STANDBY_COUNT}备"

echo "[2/3] 启动主节点"
# 检查主节点状态
PRIMARY_STATE=$(docker exec opengauss-primary su - omm -c "gs_ctl query -D /home/omm/data 2>&1" | grep -o 'db_state.*Normal' || echo 'stopped')

if echo "$PRIMARY_STATE" | grep -q "Normal"; then
    echo "  ✓ 主节点已在运行"
else
    docker exec opengauss-primary su - omm -c "gs_ctl start -D /home/omm/data -M primary > /dev/null 2>&1" || {
        echo "错误: 主节点启动失败"
        exit 1
    }
    sleep 2
    echo "  ✓ 主节点启动完成"
fi

if [ $STANDBY_COUNT -gt 0 ]; then
    echo "[3/3] 启动备节点 (${STANDBY_COUNT}个)"
    for i in "${!STANDBY_CONTAINERS[@]}"; do
        standby_name="${STANDBY_CONTAINERS[$i]}"
        printf "  [%d/%d] %s ... " $((i+1)) $STANDBY_COUNT $standby_name
        
        # 检查状态
        STANDBY_STATE=$(docker exec $standby_name su - omm -c "gs_ctl query -D /home/omm/data 2>&1" | grep -o 'db_state.*Normal' || echo 'stopped')
        
        if echo "$STANDBY_STATE" | grep -q "Normal"; then
            echo "已运行 ✓"
        else
            docker exec $standby_name su - omm -c "
                gs_ctl build -D /home/omm/data -M standby > /dev/null 2>&1
                gs_ctl start -D /home/omm/data -M standby > /dev/null 2>&1
            " > /dev/null 2>&1 || { echo "❌ 失败"; continue; }
            sleep 1
            echo "✓"
        fi
    done
else
    echo "[3/3] 跳过备节点启动 (无备节点)"
fi

echo "✓ 集群启动完成"
