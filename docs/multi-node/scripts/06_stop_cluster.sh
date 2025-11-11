#!/bin/bash
# openGauss 多节点集群 - 停止脚本
# 在主节点容器内以 root 身份运行此脚本

set -e

echo "=== openGauss 集群停止 ==="
echo ""

# 按顺序停止：先备节点，后主节点
for standby in standby2 standby1; do
    container="opengauss-${standby}"
    
    echo "停止 $standby..."
    docker exec $container su - omm -c "
        export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
        export PATH=\$GAUSSHOME/bin:\$PATH
        export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
        
        gs_ctl stop -D /home/omm/data
    " || echo "  $standby 已停止或未运行"
    
    echo "  ✓ $standby 停止完成"
done

echo ""
echo "停止主节点..."
docker exec opengauss-primary su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gs_ctl stop -D /home/omm/data
" || echo "  主节点已停止或未运行"

echo "  ✓ 主节点停止完成"
echo ""

echo "=== 集群停止完成 ==="
