# openGauss 使用说明

## 1. 宿主机相关准备

1. [安装 docker](https://www.docker.com/get-started)，每次连接 docker 容器前**务必确保 Docker Desktop 已启动**。
2. 安装 [git](https://git-scm.com/downloads)，用于克隆代码仓库。
3. 安装 [VS Code](https://code.visualstudio.com/)，并安装相关插件：

   > 具体使用方法参考：[在 VS Code 中使用 docker](https://zhuanlan.zhihu.com/p/496213879)。
   >
4. 在宿主机上拉取镜像，[opengauss镜像](https://hub.docker.com/repository/docker/xcg0/opengauss-openeuler_22.03/general)、[benchbase镜像](https://hub.docker.com/repository/docker/xcg0/benchbase-opengauss/general)：

   ```bash
   # opengauss 单节点数据库
   docker pull xcg0/opengauss-openeuler_22.03:x86_64

   # benchbase postgre
   docker pull xcg0/benchbase-opengauss:latest
   ```

   > 单节点部署请参考：[单节点快速部署指南](./docs/single-node.md)
   >
   > openGauss 数据库内核调试请参考：[openGauss 数据库内核调试指南
   > ](./docs/debug.md)
   >

---

## 2. 多节点集群部署

> 更详细的多节点集群部署文档请参考：[多节点部署脚本详细说明](tools/multi-node/README.md)
>
> 目前仅支持基于流复制（Streaming Replication）的主备部署，后续如果支持 DCF 模式（使用 Paxos 共识算法）会同步更新文档。详细对比请参考：[DCF vs 流复制](./docs/DCF_vs_StreamingReplication.md)

集群架构如下：

```mermaid
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

### 2.1 快速开始

使用一键部署脚本 `multi-node.sh` 进行多节点集群部署。用法：`./multi-node.sh [-n 备节点数] [-m 复制模式] [-s 仅执行某一步骤] [-y 所有步骤自动确认]`

```bash
cd scripts

./multi-node.sh -h  # 显示帮助信息

#./multi-node.sh     # 1主2备，ANY1模式，全部执行，每步确认（默认）
./multi-node.sh -y  # 1主2备，ANY1模式，全部执行，自动确认
#./multi-node.sh -n 2 -m ANY1 -y # 同上

```


| 参数          | 说明              | 默认值   | 示例                      |
| ------------- | ----------------- | -------- | ------------------------- |
| `-n NUMBER` | 备节点数量 (1-10) | 2        | `-n 4` (1主4备)         |
| `-m MODE`   | 复制模式          | ANY1     | `-m ANY2` (任意2个同步) |
| `-y`        | 自动确认所有步骤  | 手动确认 | `-y` (无交互模式)       |
| `-h`        | 显示帮助信息      | -        | `-h`                    |
| `-s`        | 执行特定某个步骤  | 全部步骤 | `-s start`、`-s 4`    |

> `-m` 可选的复制模式包括：
>
> - `ANYN`：任意 N 个备库为同步，其他为异步
> - `FIRSTN`：前 N 个备库为同步，其他为异步
> - `SYNC`：任意 N 个备库为同步，其他为异
> - `ASYNC`：所有备库均为异步
>
> `-s` 可选步骤有 `1 或 create`、`2 或 ssh`、``3 或 init``、`4 或 start`、`5 或 verify`、`stop `、`restart`

执行流程图：

```mermaid
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

> 01 ~ 05 脚本均位于 `scripts/multi-node/` 目录下。
>
> `01_create_containers.sh` 在容器初始化时默认使用 [Github 代码仓库](https://github.com/XCG0/HIT-HATM)，如遇网络问题会切换到 [Gitee 镜像仓库](https://gitee.com/XuChGu/HIT-HATM)。

### 2.2 常用管理命令

```bash
# 查看集群状态
docker exec opengauss-primary su - omm -c "gs_ctl query -D /home/omm/data"

# 启动集群
./scripts/multi-node.sh -s start

# 停止集群
./scripts/multi-node.sh -s stop

# 清理环境
docker stop $(docker ps -q -f name=opengauss)
docker rm $(docker ps -aq -f name=opengauss)
docker network rm opengauss-network
```

---

## 3. BenchBase 基准测试工具使用说明

> 详细文档请参考：[BenchBase 使用指南](tools/benchBase/README.md)

BenchBase（原 OLTP-Bench）是 CMU 数据库组开发的**多数据库 SQL 基准测试框架**，通过 JDBC 连接支持多种关系型数据库。

测试架构如下：

```mermaid
graph LR
    subgraph Docker["Docker 环境"]
        BB[BenchBase 容器]
        Primary[Primary 主节点]
        Standby1[Standby1 备节点]
        Standby2[Standby2 备节点]
	StandbyN[StandbyN 备节点]
    end

    Config["config/<br/>配置文件夹"] -.调整配置<br/>挂载.-> BB
    BB -->|JDBC 连接| Primary
    Primary -.流复制.-> Standby1
    Primary -.流复制.-> Standby2
    Primary -.流复制.-> StandbyN
    BB -.生成结果<br/>挂载.-> Results["results/<br/>结果文件夹"]
  
    Vol1["主机:<br/>scripts/benchBase/config/"] -.volume.-> Config
    Vol2["主机:<br/>scripts/benchBase/results/"] -.volume.-> Results

    classDef bbStyle fill:#E8F5E9,stroke:#333,stroke-width:2px
    classDef primaryStyle fill:#FFD54F,stroke:#333,stroke-width:2px
    classDef standbyStyle fill:#B3E5FC,stroke:#333,stroke-width:2px
    classDef configStyle fill:#FFF9C4,stroke:#333,stroke-width:2px
    classDef resultsStyle fill:#F8BBD0,stroke:#333,stroke-width:2px

    class BB bbStyle
    class Primary primaryStyle
    class Standby1,Standby2,StandbyN standbyStyle
    class Config configStyle
    class Results resultsStyle

```

### 3.1 支持的基准测试

| 基准测试               | 类型      | 应用场景     | 说明                             |
| ---------------------- | --------- | ------------ | -------------------------------- |
| **TPC-C**        | OLTP      | 订单处理系统 | 批发供应商业务，测试事务处理能力 |
| **SmallBank**    | OLTP      | 银行应用     | 简单银行交易，轻量级测试         |
| **YCSB**         | Key-Value | 云服务基准   | 简单读写操作，测试扩展性         |
| **TATP**         | OLTP      | 电信应用     | 高并发简单事务                   |
| **TPC-H**        | OLAP      | 决策支持系统 | 复杂分析查询                     |
| **Wikipedia**    | Web应用   | 维基百科     | 真实Web访问模式                  |
| **CH-benCHmark** | HTAP      | 混合负载     | OLTP和OLAP混合测试               |

### 3.2 快速开始

```bash
cd scripts

# 运行 TPC-C 测试（默认）
./benchBase.sh

# 运行其它测试
./benchBase.sh -t smallbank
./benchBase.sh -t ycsb
./benchBase.sh -t tpch
./benchBase.sh -t tatp
./benchBase.sh -t wikipedia
./benchBase.sh -t chbenchmark
```

执行流程说明：

```mermaid
flowchart LR
    A["构建 BenchBase 容器\n（01_start_benchbase.sh）"] --> C["配置数据库与表结构\n（02_create_schema.sh）"]
    C --> D["加载数据\n（03_load_data.sh）"]
    D --> E["运行测试\n（04_run_benchmark.sh）"]
    E --> F["分析结果\n（05_analyze_results.sh）"]

    style A fill:#FFE0B2
    style C fill:#BBDEFB
    style D fill:#F8BBD0
    style E fill:#E1BEE7
    style F fill:#FFF9C4
```

> 01 ~ 05 脚本均位于 `scripts/benchBase/` 目录下。

### 3.3 配置文件

所有配置文件位于 `tools/benchBase/config/` 目录，`tools/benchBase/config/postgres/` 下有针对 PostgreSQL 的官方示例配置：

```bash
# 从模板创建其他基准测试配置（以 tpcc 为例，注意已经配置过了）
cp config/postgres/sample_tpcc_config.xml config/tpcc_config.xml
```

> 注意从模板创建配置文件后修改下面几行：
>
> ```xml
>
> <!-- 数据库: benchbase_db, 用户: benchbase, 密码: benchbase@123 (MD5加密) -->
> <url>jdbc:postgresql://172.18.0.10:5432/benchbase_db?…………</url>
> <username>benchbase</username>
> <password>benchbase@123</password>
> ```

### 3.4 测试结果

测试结果保存在 `tools/benchBase/results/` 目录，以“测试名+日期”为名的子文件夹中：

```bash
# 查看自动生成的文本报告
cat tools/benchBase/results/<测试名+日期>/tpcc_result.txt

# 查看 JSON 格式详细结果
cat tools/benchBase/results/<测试名+日期>/tpcc_*.summary.json

# 查看所有结果文件
ls -lh tools/benchBase/results/<测试名+日期>/
```

**关键性能指标**：

- **Throughput (tpmC)** - 每分钟事务数（TPC-C 核心指标）
- **P50/P95/P99 Latency** - 延迟百分位数
- **Goodput** - 有效吞吐量
