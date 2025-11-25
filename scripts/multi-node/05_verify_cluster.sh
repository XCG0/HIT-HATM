#!/bin/bash
# openGauss 多节点集群 - 自动验证脚本（支持多种复制模式）
# 在宿主机上运行此脚本

set -e

echo "=== openGauss 集群自动验证 ==="
echo ""

# ==================== 发现集群节点 ====================
PRIMARY_IP="172.18.0.10"
STANDBY_COUNT=0

# 检查主节点
if ! docker ps -q -f name=opengauss-primary | grep -q .; then
    echo "❌ 验证失败: 未找到主节点"
    exit 1
fi

# 统计备节点数量
for i in {1..10}; do
    if docker ps -q -f name=opengauss-standby$i | grep -q .; then
        STANDBY_COUNT=$((STANDBY_COUNT + 1))
    fi
done

# 获取复制模式配置
SYNC_CONFIG=$(docker exec opengauss-primary su - omm -c "gsql -d postgres -t -c \"SHOW synchronous_standby_names;\"" 2>/dev/null | tr -d ' \n' | sed "s/'//g")

echo "📊 集群配置: 1 主节点 + $STANDBY_COUNT 备节点"
echo "🔧 复制模式: ${SYNC_CONFIG:-异步模式}"
echo ""

# ==================== 验证项 ====================
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# 解析复制模式
REPL_MODE="ASYNC"
EXPECTED_SYNC_COUNT=0

if [ -n "$SYNC_CONFIG" ] && [ "$SYNC_CONFIG" != "" ]; then
    if [[ "$SYNC_CONFIG" =~ ^ANY[[:space:]]*([0-9]+) ]]; then
        REPL_MODE="ANY"
        EXPECTED_SYNC_COUNT=${BASH_REMATCH[1]}
    elif [[ "$SYNC_CONFIG" =~ ^FIRST[[:space:]]*([0-9]+) ]]; then
        REPL_MODE="FIRST"
        EXPECTED_SYNC_COUNT=${BASH_REMATCH[1]}
    elif [[ "$SYNC_CONFIG" =~ ^\* ]]; then
        REPL_MODE="SYNC_ALL"
        EXPECTED_SYNC_COUNT=$STANDBY_COUNT
    fi
fi

# 1. 验证主节点状态
echo -n "🔍 [1/5] 检查主节点状态... "
PRIMARY_STATUS=$(docker exec opengauss-primary su - omm -c "gs_ctl query -D /home/omm/data" 2>&1)
if echo "$PRIMARY_STATUS" | grep -q "local_role.*:.*Primary" && echo "$PRIMARY_STATUS" | grep -q "db_state.*:.*Normal"; then
    echo "✅ 通过"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "❌ 失败"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 2. 验证备节点状态
if [ $STANDBY_COUNT -gt 0 ]; then
    echo -n "🔍 [2/5] 检查备节点状态... "
    ALL_STANDBY_OK=true
    RUNNING_COUNT=0
    for i in $(seq 1 $STANDBY_COUNT); do
        STANDBY_STATUS=$(docker exec opengauss-standby$i su - omm -c "gs_ctl query -D /home/omm/data" 2>&1)
        if echo "$STANDBY_STATUS" | grep -q "local_role.*:.*Standby" && echo "$STANDBY_STATUS" | grep -q "db_state.*:.*Normal"; then
            RUNNING_COUNT=$((RUNNING_COUNT + 1))
        else
            ALL_STANDBY_OK=false
        fi
    done
    
    if [ "$ALL_STANDBY_OK" = true ]; then
        echo "✅ 通过 (${RUNNING_COUNT}/${STANDBY_COUNT})"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "❌ 失败 (${RUNNING_COUNT}/${STANDBY_COUNT})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "🔍 [2/5] 检查备节点状态... ⊘ 跳过 (无备节点)"
fi

# 3. 验证主备复制连接
if [ $STANDBY_COUNT -gt 0 ]; then
    echo -n "🔍 [3/5] 检查复制连接... "
    REPL_COUNT=$(docker exec opengauss-primary su - omm -c "gsql -d postgres -t -c \"SELECT COUNT(*) FROM pg_stat_replication;\"" 2>/dev/null | tr -d ' ')
    
    if [ "$REPL_COUNT" -eq "$STANDBY_COUNT" ]; then
        echo "✅ 通过 (${REPL_COUNT}/${STANDBY_COUNT})"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "❌ 失败 (${REPL_COUNT}/${STANDBY_COUNT})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "🔍 [3/5] 检查复制连接... ⊘ 跳过 (无备节点)"
fi

# 4. 验证同步状态（根据复制模式验证）
if [ $STANDBY_COUNT -gt 0 ]; then
    echo -n "🔍 [4/5] 检查同步状态... "
    STREAMING_COUNT=$(docker exec opengauss-primary su - omm -c "gsql -d postgres -t -c \"SELECT COUNT(*) FROM pg_stat_replication WHERE state='Streaming';\"" 2>/dev/null | tr -d ' ')
    
    if [ "$STREAMING_COUNT" -eq "$STANDBY_COUNT" ]; then
        echo "✅ 通过 (${STREAMING_COUNT}/${STANDBY_COUNT} Streaming)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "❌ 失败 (${STREAMING_COUNT}/${STANDBY_COUNT} Streaming)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "🔍 [4/5] 检查同步状态... ⊘ 跳过 (无备节点)"
fi

# 5. 验证复制模式配置和同步备库数量
echo -n "🔍 [5/5] 检查复制模式配置... "

if [ $STANDBY_COUNT -eq 0 ]; then
    echo "⊘ 跳过 (无备节点)"
elif [ "$REPL_MODE" = "ASYNC" ]; then
    # 异步模式：所有备库应该是 Async
    ASYNC_COUNT=$(docker exec opengauss-primary su - omm -c "gsql -d postgres -t -c \"SELECT COUNT(*) FROM pg_stat_replication WHERE sync_state='Async';\"" 2>/dev/null | tr -d ' ')
    if [ "$ASYNC_COUNT" -eq "$STANDBY_COUNT" ]; then
        echo "✅ 通过 (异步模式, ${ASYNC_COUNT}/${STANDBY_COUNT} Async)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "❌ 失败 (期望 ${STANDBY_COUNT} 个 Async, 实际 ${ASYNC_COUNT})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
elif [ "$REPL_MODE" = "ANY" ]; then
    # ANY N 模式：应该有至少 N 个 Quorum 备库
    QUORUM_COUNT=$(docker exec opengauss-primary su - omm -c "gsql -d postgres -t -c \"SELECT COUNT(*) FROM pg_stat_replication WHERE sync_state='Quorum';\"" 2>/dev/null | tr -d ' ')
    if [ "$QUORUM_COUNT" -ge "$EXPECTED_SYNC_COUNT" ]; then
        echo "✅ 通过 (ANY ${EXPECTED_SYNC_COUNT} 模式, ${QUORUM_COUNT} 个 Quorum)"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ "$QUORUM_COUNT" -gt 0 ]; then
        echo "⚠️  警告 (期望至少 ${EXPECTED_SYNC_COUNT} 个 Quorum, 实际 ${QUORUM_COUNT})"
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        echo "❌ 失败 (期望至少 ${EXPECTED_SYNC_COUNT} 个 Quorum, 实际 ${QUORUM_COUNT})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
elif [ "$REPL_MODE" = "FIRST" ]; then
    # FIRST N 模式：应该有 N 个 Sync 备库
    SYNC_COUNT=$(docker exec opengauss-primary su - omm -c "gsql -d postgres -t -c \"SELECT COUNT(*) FROM pg_stat_replication WHERE sync_state='Sync';\"" 2>/dev/null | tr -d ' ')
    POTENTIAL_COUNT=$(docker exec opengauss-primary su - omm -c "gsql -d postgres -t -c \"SELECT COUNT(*) FROM pg_stat_replication WHERE sync_state='Potential';\"" 2>/dev/null | tr -d ' ')
    TOTAL_SYNC=$((SYNC_COUNT + POTENTIAL_COUNT))
    
    if [ "$SYNC_COUNT" -eq "$EXPECTED_SYNC_COUNT" ]; then
        echo "✅ 通过 (FIRST ${EXPECTED_SYNC_COUNT} 模式, ${SYNC_COUNT} Sync + ${POTENTIAL_COUNT} Potential)"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ "$TOTAL_SYNC" -ge "$EXPECTED_SYNC_COUNT" ]; then
        echo "⚠️  警告 (FIRST ${EXPECTED_SYNC_COUNT}, 有 ${SYNC_COUNT} Sync + ${POTENTIAL_COUNT} Potential)"
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        echo "❌ 失败 (期望 ${EXPECTED_SYNC_COUNT} 个同步备库, 实际 ${TOTAL_SYNC})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    # 其他模式
    if [ -n "$SYNC_CONFIG" ]; then
        echo "✅ 通过 (${SYNC_CONFIG})"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "⚠️  异步模式"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
fi

# ==================== 显示详细信息 ====================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 复制状态详情"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $STANDBY_COUNT -gt 0 ]; then
    docker exec opengauss-primary su - omm -c "
        gsql -d postgres -c \"
        SELECT 
            application_name AS 节点,
            client_addr AS IP地址,
            state AS 状态,
            sync_state AS 同步状态,
            sync_priority AS 优先级
        FROM pg_stat_replication
        ORDER BY sync_priority DESC, application_name;
        \"
    " 2>/dev/null || echo "❌ 无法获取复制状态"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📌 同步状态说明"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    case "$REPL_MODE" in
        "ANY")
            echo "🔹 模式: ANY ${EXPECTED_SYNC_COUNT}"
            echo "   - 至少 ${EXPECTED_SYNC_COUNT} 个备库确认事务即可提交"
            echo "   - 期望状态: 至少 ${EXPECTED_SYNC_COUNT} 个 Quorum"
            echo "   - 说明: openGauss 会将所有符合条件的备库标记为 Quorum"
            ;;
        "FIRST")
            echo "🔹 模式: FIRST ${EXPECTED_SYNC_COUNT}"
            echo "   - 前 ${EXPECTED_SYNC_COUNT} 个备库确认事务才能提交"
            echo "   - 期望状态: ${EXPECTED_SYNC_COUNT} 个 Sync (按优先级)"
            ;;
        "SYNC_ALL")
            echo "🔹 模式: 全同步"
            echo "   - 所有备库都必须确认事务"
            echo "   - 期望状态: 所有备库为 Sync"
            ;;
        "ASYNC")
            echo "🔹 模式: 异步复制"
            echo "   - 主库不等待备库确认"
            echo "   - 期望状态: 所有备库为 Async"
            ;;
    esac
else
    echo "（无备节点）"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 验证结果汇总"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 通过: $PASS_COUNT"
if [ $WARN_COUNT -gt 0 ]; then
    echo "⚠️  警告: $WARN_COUNT"
fi
echo "❌ 失败: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    if [ $WARN_COUNT -eq 0 ]; then
        echo "🎉 集群验证通过！"
    else
        echo "✓ 集群验证通过 (存在 ${WARN_COUNT} 个警告)"
    fi
    exit 0
else
    echo ""
    echo "⚠️  集群存在问题，请检查失败项"
    exit 1
fi
