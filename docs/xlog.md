# 1. WAL日志概述

## 1.1 什么是WAL日志？

WAL（Write-Ahead Logging，预写式日志）是 openGauss 数据库的核心机制，用于保证数据库的原子性、一致性和持久性（ACID 属性）。所有数据修改在写入数据文件之前，必须首先写入 WAL 日志。

## 1.2 WAL日志的主要作用

数据恢复：系统崩溃后，通过重放WAL日志恢复数据

主备同步：主备集群间通过WAL日志实现数据同步

时间点恢复：支持将数据库恢复到任意时间点

数据一致性：确保事务的完整性和一致性

## 1.3 WAL日志的物理存储

```text
/home/omm/data/pg_xlog/
├── 000000010000000000000099  # WAL段文件（16MB）
├── 00000001000000000000009A
├── ...
└── archive_status/           # 归档状态目录
```

文件名格式：00000001 00000000 00000099

- 前8位：时间线（timeline）
- 中间8位：逻辑日志文件号（高位）
- 最后8位：逻辑日志文件号（低位）

# 2. WAL日志结构详解

## 2.1 WAL段文件内部结构

```text
+----------------+----------------+----------------+----------------+
|  页头(8192字节) |  记录1         |  记录2         |  ...           |
+----------------+----------------+----------------+----------------+
```

## 2.2 WAL记录格式

每个 WAL 记录包含以下部分：

### 2.2.1 头部信息（Basic Info）

```bash
REDO @ 0/97E14138;          # 记录起始位置
LSN 0/97E14188:             # 当前记录的逻辑序列号
prev 0/97E14108;            # 前一个记录的LSN
xid 0;                      # 事务ID（0=系统事务）
term 1;                     # 分布式事务任期
len 40;                     # 主数据长度
total 74;                   # 记录总长度（含头部）
crc 955827233;              # CRC32校验和
desc: Standby - XLOG_RUNNING_XACTS  # 资源管理器 - 记录类型
```

### 2.2.2 系统信息（System Info）

```bash
SYSID 0;                    # 系统标识符
record_origin 0;            # 记录来源（0=本地，1=远程）
max_block_id 4294967295;    # 最大块ID（-1表示无块）
readSegNo 151;              # 读取的WAL段号
readOff 14761984;           # 在段内的偏移量
readPageTLI 0;              # 读取页的时间线
curReadSegNo 0;             # 当前读取段号
curReadOff 0;               # 当前读取偏移
latestPagePtr 0/97E14000;   # 最新页指针
latestPageTLI 1;            # 最新页时间线
currRecPtr 0/97E14138;      # 当前记录指针
```

### 2.2.3 私有区域信息（Private Area）

```bash
PRIVATE @0/97000000-0/98000000;  # 私有内存区域范围
TLI 1;                            # 时间线ID
endptr_reached 0;                 # 是否到达结束指针（0=否）
```

### 2.2.4 主数据信息（Main Data）

```bash
MAINDATA main_data_len 40;   # 主数据实际长度
main_data_bufsz 40;          # 主数据缓冲区大小
```

# 3. WAL记录类型说明

## 3.1 事务管理类记录

|         记录类型         |   描述   |   典型场景   |
| :----------------------: | :------: | :----------: |
|     `XLOG_COMMIT`     | 事务提交 | 事务成功完成 |
|      `XLOG_ABORT`      | 事务中止 |   事务回滚   |
| `XLOG_XACT_ASSIGNMENT` | 事务分配 |  新事务开始  |

## 3.2 检查点与备份记录

|       记录类型       |    描述    |         关键字段         |
| :-------------------: | :--------: | :-----------------------: |
|  `XLOG_CHECKPOINT`  | 检查点记录 | redo 点、next_csn、时间戳 |
|  `XLOG_BACKUP_END`  |  备份结束  |       备份结束位置       |
| `XLOG_BACKUP_START` |  备份开始  |       备份开始位置       |

## 3.3 数据操作记录

|         记录类型         |   描述   |          对应SQL操作          |
| :----------------------: | :------: | :---------------------------: |
|   `XLOG_HEAP_INSERT`   | 堆表插入 |          `INSERT`          |
|   `XLOG_HEAP_UPDATE`   | 堆表更新 |          `UPDATE`          |
|   `XLOG_HEAP_DELETE`   | 堆表删除 |          `DELETE`          |
| `XLOG_HEAP_HOT_UPDATE` | HOT更新 | `UPDATE（Heap Only Tuple）` |

## 3.4 备用节点记录

|        记录类型        |     描述     |         作用         |
| :--------------------: | :----------: | :-------------------: |
|  `XLOG_STANDBY_CSN`  | 备用节点 CSN |    主备同步控制点    |
| `XLOG_RUNNING_XACTS` | 运行中的事务 |     记录事务状态     |
|    `XLOG_SWITCH`    |   WAL 切换   | 切换到下一个 WAL 文件 |

## 3.5 检查点记录详解

```bash
XLOG - checkpoint: 
  redo 0/97E14108;           # 重做起始位置
  len 120;                   # 记录长度
  next_csn 80975;           # 下一个CSN（提交序列号）
  recent_global_xmin 93319; # 最近的全局xmin
  tli 1;                    # 时间线
  fpw false;                # 是否包含全页写
  xid 93321;                # 事务ID
  oid 24576;                # 对象ID
  multi 1389;               # 多事务信息
  offset 3023;              # 偏移量
  oldest xid 11555 in DB 14809;  # 最旧的事务ID
  oldest running xid 93321;       # 最旧的运行中事务ID
  oldest xid with epoch having undo 93319;  # 带epoch的最旧事务
  online at Sun Jan 25 09:28:42 2026;  # 检查点时间
  remove_seg 0/1;           # 需要删除的段
```

# 4. pg_xlogdump工具使用指南

## 4.1 工具概述

`pg_xlogdump` 是 openGauss 自带的 WAL 日志分析工具，用于解析和显示 WAL 日志内容。

## 4.2 基本语法

```bash
pg_xlogdump [选项]... [STARTSEG [ENDSEG]]
```

## 4.3 常用选项详解

### 4.3.1 输入输出控制

|     选项     |  简写  |             说明             |             示例             |
| :----------: | :----: | :--------------------------: | :---------------------------: |
|  `--path`  | `-p` |         WAL文件目录         | `-p /home/omm/data/pg_xlog` |
| `--start` | `-s` |           起始LSN           |       `-s 0/99000028`       |
|  `--end`  | `-e` |           结束LSN           |       `-e 0/99000148`       |
| `--limit` | `-n` |        显示记录数限制        |          `-n 100`          |
| `--follow` | `-f` | 持续跟踪（类似 `tail -f`） |                              |

### 4.3.2 过滤选项

|      选项      |  简写  |       说明       |         示例         |
| :------------: | :----: | :--------------: | :-------------------: |
|   `--rmgr`   | `-r` | 按资源管理器过滤 | `-r XLOG（检查点）` |
|   `--xid`   | `-x` |   按事务ID过滤   |     `-x 93321`     |
| `--timeline` | `-t` |   按时间线过滤   |       -`t 1`       |

### 4.3.3 输出格式控制

|       选项       |  简写  |      说明      |  示例  |
| :---------------: | :----: | :------------: | :----: |
|   `--verbose`   | `-v` |    详细输出    | `-v` |
| `--bkp-details` | `-b` | 显示备份块详情 | `-b` |
|    `--stats`    | `-z` |  显示统计信息  | `-z` |

### 4.3.4 共享存储选项（DSS）

|       选项       |           说明           |             示例             |
| :--------------: | :----------------------: | :---------------------------: |
| `--enable-dss` |     启用共享存储模式     |       `--enable-dss`       |
| `--socketpath` |      DSS套接字路径      | `--socketpath=/path/to/dss` |
|  `--size -S`  | WAL文件大小（默认512GB） |          `-S 256G`          |

## 4.4 实用命令示例

### 4.4.1 基础查看

```bash
# 查看所有 x_log 文件
cd /home/omm/data/pg_xlog
ls -lh

# 查看单个WAL文件
/home/omm/waltools/pg_xlogdump -p /home/omm/data/pg_xlog 000000010000000000000099

# 查看多个连续文件
/home/omm/waltools/pg_xlogdump -p /home/omm/data/pg_xlog 000000010000000000000099 00000001000000000000009A
```

### 4.4.2 精确过滤

```bash
# 只查看检查点记录
/home/omm/waltools/pg_xlogdump -r XLOG -p /home/omm/data/pg_xlog 000000010000000000000099

# 查看特定事务
/home/omm/waltools/pg_xlogdump -x 93321 -p /home/omm/data/pg_xlog 000000010000000000000099

# 查看特定时间范围的记录
/home/omm/waltools/pg_xlogdump -s 0/97E12620 -e 0/97E14468 -p /home/omm/data/pg_xlog 000000010000000000000099


for wal_file in /home/omm/data/pg_xlog/00000001000000000000009*; do     echo "=== Checking: $(basename $wal_file) ===";     /home/omm/waltools/pg_xlogdump -p /home/omm/data/pg_xlog $(basename $wal_file) 2>/dev/null |       grep -E "XLOG_HEAP_CREATE|XLOG_HEAP_INSERT|XLOG_HEAP_UPDATE|XLOG_HEAP_DELETE"; done
```

### 4.4.3 详细分析

```bash
# 显示详细信息（包括备份块）
/home/omm/waltools/pg_xlogdump -b -v -p /home/omm/data/pg_xlog 000000010000000000000099

# 显示统计信息
/home/omm/waltools/pg_xlogdump -z -p /home/omm/data/pg_xlog 000000010000000000000099

# 持续监控WAL变化
/home/omm/waltools/pg_xlogdump -f -p /home/omm/data/pg_xlog
```

## 4.5 输出解析技巧

### 4.5.1 使用管道过滤

```bash
# 提取所有检查点时间
/home/omm/waltools/pg_xlogdump -p /home/omm/data/pg_xlog 000000010000000000000099 | \
  grep -o "online at [^;]*" | \
  cut -d' ' -f3-

# 统计不同类型记录数量
/home/omm/waltools/pg_xlogdump -p /home/omm/data/pg_xlog 000000010000000000000099 | \
  grep -o "desc: [A-Z_]*" | \
  sort | uniq -c | sort -rn

# 查找特定事务的所有相关记录
/home/omm/waltools/pg_xlogdump -p /home/omm/data/pg_xlog 000000010000000000000099 | \
  grep "xid 93321"

# 根据 oid 查找某张表的相关记录
gsql -d benchbase_db -U benchbase -W 'benchbase@123' -p 5432
SELECT oid, relname FROM pg_class WHERE relname IN ('warehouse','district','customer','orders','order_line','stock','history','new_order','item');
/home/omm/waltools/pg_xlogdump -p /home/omm/data/pg_xlog 000000010000000000000096 | grep 'rel .*16393'

# 查找 DDL 操作记录
for wal_file in /home/omm/data/pg_xlog/00000001000000000000009*; do
    echo "=== Checking: $(basename $wal_file) ==="
    /home/omm/waltools/pg_xlogdump -p /home/omm/data/pg_xlog $(basename $wal_file) 2>/dev/null | \
    grep -E "XLOG_HEAP_CREATE|XLOG_HEAP_INSERT|XLOG_HEAP_UPDATE|XLOG_HEAP_DELETE"
done

```

### 4.5.2 自动化脚本示例

```bash
#!/bin/bash
# wal_analyzer.sh

WAL_DIR="/home/omm/data/pg_xlog"
WAL_FILE="$1"
OUTPUT_PREFIX="wal_analysis_$(date +%Y%m%d_%H%M%S)"

echo "=== WAL Analysis Report ===" > "${OUTPUT_PREFIX}.txt"
echo "File: $WAL_FILE" >> "${OUTPUT_PREFIX}.txt"
echo "Time: $(date)" >> "${OUTPUT_PREFIX}.txt"

# 1. 统计信息
echo "" >> "${OUTPUT_PREFIX}.txt"
echo "=== Record Statistics ===" >> "${OUTPUT_PREFIX}.txt"
/home/omm/waltools/pg_xlogdump -z -p "$WAL_DIR" "$WAL_FILE" >> "${OUTPUT_PREFIX}.txt"

# 2. 检查点时间线
echo "" >> "${OUTPUT_PREFIX}.txt"
echo "=== Checkpoint Timeline ===" >> "${OUTPUT_PREFIX}.txt"
/home/omm/waltools/pg_xlogdump -r XLOG -p "$WAL_DIR" "$WAL_FILE" | \
  grep -o "online at [^;]*" >> "${OUTPUT_PREFIX}.txt"

# 3. 事务分析
echo "" >> "${OUTPUT_PREFIX}.txt"
echo "=== Transaction Analysis ===" >> "${OUTPUT_PREFIX}.txt"
/home/omm/waltools/pg_xlogdump -p "$WAL_DIR" "$WAL_FILE" | \
  grep -E "xid [0-9]+" | \
  awk '{print $4}' | \
  sort -u | \
  awk '{print "Found transaction: " $1}' >> "${OUTPUT_PREFIX}.txt"

echo "Analysis complete: ${OUTPUT_PREFIX}.txt"
```
