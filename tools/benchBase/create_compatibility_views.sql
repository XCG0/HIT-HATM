-- ============================================================================
-- BenchBase 兼容性视图创建脚本
-- 功能: 为 openGauss 创建 PostgreSQL 兼容的系统视图
-- 说明: 解决 BenchBase DBCollector 查询不存在视图的问题
-- ============================================================================

-- 创建 pg_stat_archiver 兼容视图
-- PostgreSQL 原始视图包含归档进程的统计信息
-- openGauss 没有此视图，创建一个返回空结果的兼容视图

DROP VIEW IF EXISTS pg_stat_archiver CASCADE;

CREATE OR REPLACE VIEW pg_stat_archiver AS
SELECT
    0::bigint AS archived_count,          -- 成功归档的 WAL 文件数
    0::bigint AS last_archived_wal,       -- 最后归档的 WAL 文件名（实际是文本，这里简化）
    NULL::timestamp AS last_archived_time,-- 最后归档时间
    0::bigint AS failed_count,            -- 归档失败次数
    NULL::text AS last_failed_wal,        -- 最后失败的 WAL 文件名
    NULL::timestamp AS last_failed_time,  -- 最后失败时间
    NULL::timestamp AS stats_reset;
-- 统计重置时间

-- 授权给所有用户查询
GRANT SELECT ON pg_stat_archiver TO PUBLIC;

-- 显示创建结果
\echo '✓ 已创建 pg_stat_archiver 兼容视图'

-- 验证视图
SELECT * FROM pg_stat_archiver;