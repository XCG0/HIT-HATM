# openGauss 部署方式对比: DCF vs 流复制

## 概述

当前项目使用的是 **基于流复制(Streaming Replication)的主备部署**，而文档中介绍的是 **基于 DCF (Distributed Consensus Framework) 的分布式一致性部署**。

---

## 核心区别对比

| 对比项 | 流复制 (当前使用) | DCF 模式 (文档介绍) |
|--------|------------------|-------------------|
| **一致性协议** | 基于 WAL 日志流复制 | 基于 Paxos/Raft 共识算法 |
| **选主机制** | 手动/CM 工具选主 | 自动选主 (基于优先级) |
| **复制方式** | 异步/同步流复制 | Multi-Paxos 日志复制 |
| **配置复杂度** | 较简单 | 需要 OM 工具配置 XML |
| **部署工具** | gs_initdb + 手动配置 | OM (运维管理) 工具 |
| **故障恢复** | 需手动干预 | 自动故障转移 |
| **少数派强起** | 不支持 | 支持 (紧急场景) |
| **在线扩缩容** | 复杂 | 简单 (gs_ctl member 命令) |
| **角色类型** | Primary/Standby | LEADER/FOLLOWER/LOGGER/PASSIVE 等 |

---

## 详细对比

### 1. **架构设计**

#### 流复制 (当前)
```
Primary (主库)
    ↓ WAL Streaming
Standby1 ← walreceiver
Standby2 ← walreceiver
```
- 主库通过 WAL Sender 发送日志
- 备库通过 WAL Receiver 接收日志
- 基于 PostgreSQL 原生流复制机制

#### DCF 模式
```
LEADER (选举产生)
    ↓ Paxos 协议
FOLLOWER1 ← DCF 复制
FOLLOWER2 ← DCF 复制
LOGGER    ← 仅日志副本
```
- 基于 Paxos 共识算法
- 多数派达成一致后提交
- 自动选举和故障转移

### 2. **配置方式**

#### 流复制配置 (当前使用)
```bash
# postgresql.conf
synchronous_standby_names = 'ANY 1(standby1,standby2)'
wal_level = hot_standby
max_wal_senders = 10

# replconninfo
replconninfo1 = 'localhost=... remotehost=... application_name=standby1'
```

#### DCF 配置 (需要 OM 工具)
```xml
<!-- cluster_config.xml -->
<PARAM name="enable_dcf" value="on"/>
<PARAM name="dcf_config" value='[
  {"stream_id":1,"node_id":1,"ip":"192.168.0.11","port":17783,"role":"LEADER"},
  {"stream_id":1,"node_id":2,"ip":"192.168.0.12","port":17783,"role":"FOLLOWER"},
  {"stream_id":1,"node_id":3,"ip":"192.168.0.13","port":17783,"role":"FOLLOWER"}
]'/>
```

### 3. **同步模式**

#### 流复制
- **ASYNC**: 完全异步，主库不等待
- **ANY N**: 至少 N 个备库确认 (Quorum)
- **FIRST N**: 前 N 个备库确认 (Sync)
- 基于 `synchronous_standby_names` 配置

#### DCF
- **多数派模式**: 超过半数节点同意即提交
- **策略化多数派**: 指定特定节点必须包含
- **少数派模式**: 紧急场景下强制启动
- 基于 Paxos 协议自动协商

### 4. **故障处理**

#### 流复制
```bash
# 手动故障转移
pg_ctl promote -D /data/standby

# 或使用 CM 工具
cm_ctl switchover -n <node_id>
```
- 需要人工介入或外部工具
- 备库需要手动提升为主库
- 可能出现脑裂问题

#### DCF
```bash
# 自动故障转移
# 无需人工干预，DCF 自动选举新 LEADER

# 查询 DCF 状态
gs_ctl query -D /data
# 输出包含 dcf_replication_info
```
- 自动检测主节点故障
- 基于优先级自动选举
- Paxos 协议保证不会脑裂

### 5. **扩缩容操作**

#### 流复制
```bash
# 添加备库 (复杂)
1. gs_basebackup 从主库备份
2. 配置 recovery.conf
3. 配置 postgresql.conf
4. 修改主库 synchronous_standby_names
5. 重启/重载配置
```

#### DCF
```bash
# 添加节点 (简单)
gs_ctl member --operation=add --nodeid=4 \
  --ip=192.168.0.14 --port=17783 -D /data

# 删除节点
gs_ctl member --operation=remove --nodeid=4 -D /data
```
- 在线操作，5 分钟完成
- 无需重启数据库
- 自动同步数据