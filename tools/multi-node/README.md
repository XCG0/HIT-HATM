# openGauss 主备集群部署指南

> 🚀 **一键部署 | 动态扩展 | 多种复制模式**
> 基于 Docker 容器的 openGauss 高可用集群快速部署方案

[![openGauss](https://img.shields.io/badge/openGauss-3.x-blue)](https://opengauss.org/)
[![Docker](https://img.shields.io/badge/Docker-20.10+-blue)](https://www.docker.com/)

---

## 📋 目录

- [快速开始](#快速开始)
- [集群架构](#集群架构)
- [部署流程](#部署流程)
- [复制模式](#复制模式)
- [验证与监控](#验证与监控)
- [技术细节](#技术细节)
- [参考文献](#参考文献)

---

## 🚀 快速开始

### 一键部署

```bash
# 进入脚本目录
cd scripts

# 自动部署（1主2备，ANY1模式）
./multi-node.sh -y

# 自定义配置
./multi-node.sh -n 4 -m ANY2  # 1主4备，ANY2模式
```

### 手动部署

```mermaid
%%{init: {"theme":"neutral"}}%%
flowchart LR
    A["初始化环境\n（01_create_containers.sh）"] --> B["配置 SSH 互信\n（02_setup_ssh.sh）"]
    B --> C["初始化集群参数\n（03_init_cluster.sh）"]
    C --> D["启动数据库集群\n（04_start_cluster.sh）"]
    D --> E["验证集群状态\n（05_verify_cluster.sh）"]

    style A fill:#E3F2FD
    style B fill:#FFF3E0
    style C fill:#E8F5E9
    style D fill:#F3E5F5
    style E fill:#FFFDE7

```

| 步骤 | 脚本                        | 参数        | 说明                       |
| ---- | --------------------------- | ----------- | -------------------------- |
| 1    | `01_create_containers.sh` | `-n N`    | 创建容器（1主N备，N=1-10） |
| 2    | `02_setup_ssh.sh`         | 无          | 配置SSH互信（可选）        |
| 3    | `03_init_cluster.sh`      | `-m MODE` | 初始化并配置复制模式       |
| 4    | `04_start_cluster.sh`     | 无          | 启动所有节点               |
| 5    | `05_verify_cluster.sh`    | 无          | 验证集群状态               |

**示例：**

```bash
cd scripts/multi-node

./01_create_containers.sh -n 3    # 创建1主3备
./02_setup_ssh.sh                  # 配置SSH（可选）
./03_init_cluster.sh -m ANY2       # 初始化，ANY2模式
./04_start_cluster.sh              # 启动集群
./05_verify_cluster.sh             # 验证状态
```

### 关键配置文件

#### postgresql.conf（主节点）

**脚本参考：** `03_init_cluster.sh` 第 94-107 行

```ini
# 网络
listen_addresses = '*'
port = 5432

# WAL复制
wal_level = hot_standby              # 支持热备[[2]](#ref2)
max_wal_senders = 10                  # 最大复制连接数
wal_keep_segments = 256               # 保留WAL段数

# 备节点
hot_standby = on                      # 允许备节点只读查询[[5]](#ref5)

# 同步复制（动态生成）
synchronous_standby_names = 'ANY 1(standby1,standby2)'  # [[6]](#ref6)[[7]](#ref7)

# 复制通道（每个备节点）
replconninfo1 = 'localhost=172.18.0.10 localport=5434 ...'  # [[1]](#ref1)
replconninfo2 = 'localhost=172.18.0.10 localport=5436 ...'
```

#### pg_hba.conf（认证）

**脚本参考：** `03_init_cluster.sh` 第 121-130 行

```ini
# 本地连接
local   all             all                         trust
host    all             all         127.0.0.1/32    trust

# 集群内部
host    all             all         172.18.0.0/16   sha256

# 流复制（每个备节点）[[11]](#ref11)
host    replication     omm         172.18.0.11/32  trust
host    replication     omm         172.18.0.12/32  trust
```

#### recovery.conf（备节点）

**脚本参考：** `03_init_cluster.sh` 第 155-160 行

```ini
standby_mode = 'on'                                          # [[12]](#ref12)
primary_conninfo = 'host=172.18.0.10 port=5432 user=omm application_name=standby1'
recovery_target_timeline = 'latest'
```

---

## 🏗️ 集群架构

### 拓扑结构

```mermaid
%%{init: {"theme":"neutral"}}%%
graph TB
    subgraph Docker["Docker 网络 (172.18.0.0/16)"]
        Primary["<b>主节点</b><br/>opengauss-primary<br/>172.18.0.10:5432"]
  
        Standby1["<b>备节点1</b><br/>opengauss-standby1<br/>172.18.0.11:5432"]
        Standby2["<b>备节点2</b><br/>opengauss-standby2<br/>172.18.0.12:5432"]
        StandbyN["<b>备节点N</b><br/>opengauss-standbyN<br/>172.18.0.10+N:5432"]
  
        Primary -->|"WAL复制+心跳"| Standby1
        Primary -->|"WAL复制+心跳"| Standby2
        Primary -.->|"最多10个备节点"| StandbyN
    end
  
    Client["应用客户端"] -->|"读写"| Primary
    Client -.->|"只读"| Standby1
  
    style Primary fill:#e3f2fd,stroke:#1976d2,stroke-width:3px
    style Standby1 fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    style Standby2 fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    style StandbyN fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px,stroke-dasharray:5 5
```

### 节点配置表

| 节点    | 容器名                 | IP地址        | 内部端口 | 宿主机端口 | 角色 |
| ------- | ---------------------- | ------------- | -------- | ---------- | ---- |
| 主节点  | `opengauss-primary`  | 172.18.0.10   | 5432     | 15432      | 读写 |
| 备节点1 | `opengauss-standby1` | 172.18.0.11   | 5432     | 15433      | 只读 |
| 备节点2 | `opengauss-standby2` | 172.18.0.12   | 5432     | 15434      | 只读 |
| 备节点N | `opengauss-standbyN` | 172.18.0.10+N | 5432     | 15432+N    | 只读 |

**脚本参考：** `01_create_containers.sh` 第 64-104 行

### 网络通信

```mermaid
%%{init: {"theme":"neutral"}}%%
graph TB
    subgraph Primary["主节点 172.18.0.10"]
        P_DB[数据库<br/>5432]
        P_R1[复制1<br/>5434]
        P_H1[心跳1<br/>5435]
        P_R2[复制2<br/>5436]
        P_H2[心跳2<br/>5437]
    end
  
    subgraph S1["备节点1 172.18.0.11"]
        S1_DB[数据库<br/>5432]
        S1_R[复制<br/>5434]
        S1_H[心跳<br/>5435]
    end
  
    subgraph S2["备节点2 172.18.0.12"]
        S2_DB[数据库<br/>5432]
        S2_R[复制<br/>5436]
        S2_H[心跳<br/>5437]
    end
  
    P_R1 <-->|WAL数据| S1_R
    P_H1 <-->|健康检查| S1_H
    P_R2 <-->|WAL数据| S2_R
    P_H2 <-->|健康检查| S2_H
  
    style Primary fill:#e3f2fd
    style S1 fill:#fff3e0
    style S2 fill:#fff3e0
```

**端口分配规则：**（`03_init_cluster.sh` 第 112-115 行）

```bash
# 备节点索引 i (从0开始)
复制端口 = 5434 + i × 2
心跳端口 = 5435 + i × 2
```

| 备节点   | 索引i | 复制端口      | 心跳端口      |
| -------- | ----- | ------------- | ------------- |
| standby1 | 0     | 5434          | 5435          |
| standby2 | 1     | 5436          | 5437          |
| standby3 | 2     | 5438          | 5439          |
| standbyN | N-1   | 5434+(N-1)×2 | 5435+(N-1)×2 |

---

## 🔄 复制模式

> **理论基础：** openGauss 支持同步/异步复制和 Quorum Commit 机制[[6]](#ref6)[[7]](#ref7)

### 模式对比

| 模式             | 配置语法         | 同步节点数 | 性能     | 可靠性     | 适用场景           |
| ---------------- | ---------------- | ---------- | -------- | ---------- | ------------------ |
| **ANY1**   | `ANY 1(...)`   | 任意1个    | ⚡⚡⚡   | ⭐⭐⭐     | **生产推荐** |
| **ANY2**   | `ANY 2(...)`   | 任意2个    | ⚡⚡     | ⭐⭐⭐⭐   | 金融/关键业务      |
| **FIRST1** | `FIRST 1(...)` | 第1个      | ⚡⚡⚡   | ⭐⭐⭐     | 固定拓扑           |
| **FIRST2** | `FIRST 2(...)` | 前2个      | ⚡⚡     | ⭐⭐⭐⭐   | 跨机房             |
| **SYNC**   | `ANY N(...)`   | 全部       | ⚡       | ⭐⭐⭐⭐⭐ | 极高可靠性         |
| **ASYNC**  | `''` (空)      | 0          | ⚡⚡⚡⚡ | ⭐⭐       | 性能优先           |

**脚本实现：** `03_init_cluster.sh` 第 69-84 行

```bash
case $REPLICATION_MODE in
    ANY*)   # 任意N个确认即可
        SYNC_NUM=${REPLICATION_MODE#ANY}
        SYNC_STANDBY_CONFIG="synchronous_standby_names = 'ANY $SYNC_NUM($STANDBY_LIST)'"
        ;;
    FIRST*) # 必须等待前N个
        SYNC_NUM=${REPLICATION_MODE#FIRST}
        SYNC_STANDBY_CONFIG="synchronous_standby_names = 'FIRST $SYNC_NUM($STANDBY_LIST)'"
        ;;
    SYNC)   # 全部同步
        SYNC_STANDBY_CONFIG="synchronous_standby_names = 'ANY $STANDBY_COUNT($STANDBY_LIST)'"
        ;;
    ASYNC)  # 异步模式
        SYNC_STANDBY_CONFIG="synchronous_standby_names = ''"
        ;;
esac
```

### 事务提交流程

#### ANY N 模式（推荐）

```mermaid
%%{init: {"theme":"neutral"}}%%
sequenceDiagram
    participant C as 客户端
    participant P as 主节点
    participant S1 as 备节点1
    participant S2 as 备节点2
    participant S3 as 备节点3
  
    C->>P: COMMIT
    P->>P: 写入本地WAL
  
    par 并行发送
        P->>S1: 发送WAL
        P->>S2: 发送WAL
        P->>S3: 发送WAL
    end
  
    par 等待最快的N个
        S1-->>P: ✓ ACK (快)
        S2-->>P: ✓ ACK (快)
        Note over S3: 较慢，不等待
    end
  
    P->>C: ✓ COMMIT成功
    S3->>S3: 稍后应用WAL
  
    Note over P,S2: ANY 2: 收到2个确认即提交<br/>动态选择最快的节点
```

#### FIRST N 模式

```mermaid
%%{init: {"theme":"neutral"}}%%
sequenceDiagram
    participant C as 客户端
    participant P as 主节点
    participant S1 as 备节点1(优先级1)
    participant S2 as 备节点2(优先级2)
    participant S3 as 备节点3(优先级3)
  
    C->>P: COMMIT
    P->>P: 写入WAL
  
    par 并行发送
        P->>S1: 发送WAL
        P->>S2: 发送WAL
        P->>S3: 发送WAL
    end
  
    par 必须等待前2个
        S1-->>P: ✓ ACK (优先级1)
        S2-->>P: ✓ ACK (优先级2)
        Note over S3: 优先级3，不等待
    end
  
    P->>C: ✓ COMMIT成功
  
    Note over P,S2: FIRST 2: 必须等待优先级最高的2个<br/>如果S1或S2故障会阻塞
```

### sync_state 状态

**脚本验证：** `05_verify_cluster.sh` 第 76-88 行

| 状态          | 含义         | 阻塞事务 | 参考      |
| ------------- | ------------ | -------- | --------- |
| `Quorum`    | 法定人数模式 | ✅       | [[7]](#ref7) |
| `Sync`      | 同步模式     | ✅       | [[6]](#ref6) |
| `Potential` | 潜在同步节点 | ❌       | [[1]](#ref1) |
| `Async`     | 异步复制     | ❌       | [[6]](#ref6) |

---

## ✅ 验证与监控

### 自动验证

**脚本：** `05_verify_cluster.sh`

```bash
./05_verify_cluster.sh
```

**输出示例：**

```
=== openGauss 集群自动验证 ===

📊 集群配置: 1 主节点 + 2 备节点

🔍 [1/5] 检查主节点状态... ✅ 通过
🔍 [2/5] 检查备节点状态... ✅ 通过 (2/2)
🔍 [3/5] 检查复制连接... ✅ 通过 (2/2)
🔍 [4/5] 检查同步状态... ✅ 通过 (2/2 Streaming)
🔍 [5/5] 检查复制模式... ✅ 通过 (ANY1(standby1,standby2))

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 复制状态详情
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 节点      | IP地址        | 状态      | 同步状态  | 优先级
-----------+---------------+-----------+-----------+--------
 standby1  | 172.18.0.11  | Streaming | Quorum    | 1
 standby2  | 172.18.0.12  | Streaming | Potential | 0

🎉 集群验证通过！
```

### 监控查询

```sql
-- 主节点：查看复制状态 [[13]](#ref13)
SELECT 
    application_name AS 节点,
    client_addr AS IP,
    state AS 状态,
    sync_state AS 同步状态,
    sync_priority AS 优先级
FROM pg_stat_replication;

-- 备节点：查看复制延迟
SELECT now() - pg_last_xact_replay_timestamp() AS 延迟;
```

### 故障检测机制

```mermaid
%%{init: {"theme":"neutral"}}%%
stateDiagram-v2
    [*] --> Normal: 集群启动
  
    Normal --> 检测故障: 心跳超时(30s)
    检测故障 --> 备节点故障: 备节点无响应
    检测故障 --> 主节点故障: 主节点无响应
  
    备节点故障 --> 自动切换: ANY模式自动选择其他节点
    自动切换 --> Normal: 切换完成
  
    主节点故障 --> 手动提升: gs_ctl promote
    手动提升 --> Normal: 新主节点运行
  
    Note right of 自动切换: 应用无感知<br/>自动完成
    Note right of 手动提升: 需人工介入<br/>或使用自动化工具
```

| 故障类型   | 检测方式    | 检测时间 | 系统响应                 |
| ---------- | ----------- | -------- | ------------------------ |
| 备节点宕机 | 心跳+TCP    | ~30s     | ANY模式自动切换[[3]](#ref3) |
| 主节点宕机 | 备节点检测  | ~60s     | 需手动提升备节点         |
| 网络中断   | 心跳超时    | ~30s     | 标记为disconnected       |
| 复制延迟   | WAL发送超时 | 60s      | 事务阻塞或降级           |

---

## 🔧 技术细节

### replconninfo 配置详解

**主节点配置：**（`03_init_cluster.sh` 第 113-115 行）

```ini
replconninfo1 = 'localhost=172.18.0.10 localport=5434 localheartbeatport=5435 
                 localservice=5432 remotehost=172.18.0.11 remoteport=5434 
                 remoteheartbeatport=5435 remoteservice=5432'
```

**备节点配置：**（`03_init_cluster.sh` 第 167-175 行）

```ini
replconninfo1 = 'localhost=172.18.0.11 localport=5434 localheartbeatport=5435 
                 localservice=5432 remotehost=172.18.0.10 remoteport=5434 
                 remoteheartbeatport=5435 remoteservice=5432'
```

| 参数                   | 说明        | 主节点示例  | 备节点示例  |
| ---------------------- | ----------- | ----------- | ----------- |
| `localhost`          | 本地IP      | 172.18.0.10 | 172.18.0.11 |
| `localport`          | WAL复制端口 | 5434        | 5434        |
| `localheartbeatport` | 心跳端口    | 5435        | 5435        |
| `remotehost`         | 对端IP      | 172.18.0.11 | 172.18.0.10 |

### Docker 网络配置

**脚本参考：** `01_create_containers.sh` 第 60-62 行

```bash
# 创建专用网络
docker network create \
    --driver bridge \
    --subnet=172.18.0.0/16 \
    --gateway=172.18.0.1 \
    opengauss-network

# 静态IP分配
docker run --network opengauss-network --ip 172.18.0.10 ...  # 主节点
docker run --network opengauss-network --ip 172.18.0.11 ...  # 备节点1
```

### SSH 互信配置

**脚本参考：** `02_setup_ssh.sh`

```mermaid
%%{init: {"theme":"neutral"}}%%
graph LR
    A[启动SSH服务] --> B[生成密钥对]
    B --> C[收集公钥]
    C --> D[分发到所有节点]
    D --> E[配置免密登录]
  
    style A fill:#e3f2fd
    style E fill:#e8f5e9
```

**作用：**

- ✅ 方便节点间手动管理
- ✅ 某些工具需要SSH连接
- ⚠️ 对集群复制非必需（复制使用TCP直连）

## 🔗 参考文献

[1] openGauss 社区. "openGauss 数据库文档". Gitee openGauss Docs. https://gitee.com/opengauss/docs
_说明：openGauss 官方文档托管在 Gitee，包含完整的技术文档和开发指南_

[2] PostgreSQL Global Development Group. "Write-Ahead Logging (WAL)". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/wal-intro.html

[3] openGauss 社区. "openGauss 技术架构". openGauss 官网. https://opengauss.org/zh/
_说明：openGauss 首页包含高可靠性、故障切换等核心技术特性介绍_

[4] Docker Inc. "Networking overview". Docker Documentation. https://docs.docker.com/network/

[5] PostgreSQL Global Development Group. "Hot Standby". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/hot-standby.html

[6] PostgreSQL Global Development Group. "Synchronous Replication". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/warm-standby.html#SYNCHRONOUS-REPLICATION

[7] PostgreSQL Global Development Group. "synchronous_standby_names". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/runtime-config-replication.html#GUC-SYNCHRONOUS-STANDBY-NAMES

[8] Kleppmann, M. (2017). _Designing Data-Intensive Applications: The Big Ideas Behind Reliable, Scalable, and Maintainable Systems_. O'Reilly Media. ISBN: 978-1491903063.
在线访问: https://ddia.vonng.com/ch6/
_说明：第6章"Replication"详细讨论了数据库复制机制的设计权衡_

[9] EnMotech. "openGauss Docker 镜像". Docker Hub. https://hub.docker.com/r/enmotech/opengauss
_说明：openGauss 容器镜像的官方仓库，包含部署和配置说明_

[10] PostgreSQL Global Development Group. "Replication Configuration". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/runtime-config-replication.html

[11] PostgreSQL Global Development Group. "Client Authentication". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/client-authentication.html

[12] PostgreSQL Global Development Group. "Recovery Configuration". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/recovery-config.html

[13] PostgreSQL Global Development Group. "Monitoring Statistics". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/monitoring-stats.html

[14] PostgreSQL Global Development Group. "High Availability, Load Balancing, and Replication". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/high-availability.html
_说明：包含心跳检测和故障切换机制的详细说明_

[15] PostgreSQL Global Development Group. "Connections and Authentication". PostgreSQL 16 Documentation. https://www.postgresql.org/docs/current/runtime-config-connection.html
_说明：TCP keepalive 和连接超时参数配置_
