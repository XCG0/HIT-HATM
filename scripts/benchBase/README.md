# BenchBase多节点openGauss数据库性能测试指南

## 🚀 快速开始

如果你想快速开始测试，可以：
1. 查看 `config/` 目录下的配置文件示例
2. 运行 `./run_benchbase_tests.sh` 脚本进行交互式测试
3. 参考下面的详细指南进行深入配置

## 📁 文件结构
```
benchBase/
├── README.md                                    # 本文件
├── BenchBase_openGauss_MultiNode_Guide.md     # 详细测试指南 
├── run_benchbase_tests.sh                     # 快速启动脚本
└── config/                                     # 配置文件目录
    ├── tpcc_opengauss.xml                     # TPC-C配置
    ├── tpch_opengauss.xml                     # TPC-H配置  
    ├── ycsb_opengauss.xml                     # YCSB配置
    └── smallbank_opengauss.xml                # SmallBank配置
```

## 概述

本文档详细介绍如何使用BenchBase框架对多节点openGauss数据库集群进行性能基准测试。BenchBase是一个多线程负载生成器和多DBMS SQL基准测试框架，支持多种工作负载模式，非常适合评估分布式数据库系统的性能。

## 目录

1. [环境准备](#环境准备)
2. [BenchBase安装与配置](#benchbase安装与配置)
3. [多节点openGauss集群配置](#多节点opengauss集群配置)
4. [基准测试配置](#基准测试配置)
5. [执行测试](#执行测试)
6. [结果分析](#结果分析)
7. [高级配置](#高级配置)
8. [故障排除](#故障排除)

## 环境准备

### 系统要求

- **操作系统**: CentOS 7.6+, Ubuntu 18.04+, openEuler 20.03+
- **Java**: OpenJDK 17 或 Oracle JDK 17+
- **Maven**: 3.6.0+
- **内存**: 至少4GB可用内存
- **网络**: 集群节点间网络延迟 < 1ms (推荐)

### 硬件要求

#### 最小配置
- **CPU**: 4核心
- **内存**: 8GB
- **存储**: 100GB可用空间
- **网络**: 1Gbps

#### 推荐配置
- **CPU**: 8核心+
- **内存**: 16GB+
- **存储**: 500GB+ SSD
- **网络**: 10Gbps

## BenchBase安装与配置

### 1. 下载BenchBase

```bash
# 克隆BenchBase仓库
git clone --depth 1 https://github.com/cmu-db/benchbase.git
cd benchbase
```

### 2. 编译BenchBase

```bash
# 使用PostgreSQL配置文件编译(openGauss兼容PostgreSQL)
./mvnw clean package -P postgres

# 解压编译产物
cd target
tar xvzf benchbase-postgres.tgz
cd benchbase-postgres
```

### 3. 验证安装

```bash
# 检查BenchBase是否正常工作
java -jar benchbase.jar -h
```

## 多节点openGauss集群配置

### 集群架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Primary DN    │    │   Standby DN    │    │   Standby DN    │
│  (192.168.1.10) │    │  (192.168.1.11) │    │  (192.168.1.12) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   GTM Master    │
                    │  (192.168.1.20) │
                    └─────────────────┘
```

### 集群配置要点

1. **主节点(Primary DN)**
   - 处理读写操作
   - 负责事务协调
   - 数据同步源

2. **备节点(Standby DN)**
   - 处理只读查询
   - 数据备份
   - 故障转移目标

3. **GTM(Global Transaction Manager)**
   - 全局事务管理
   - 分布式事务协调
   - MVCC支持

### 连接配置

```bash
# 主节点连接信息
PRIMARY_HOST=192.168.1.10
PRIMARY_PORT=5432
DATABASE_NAME=benchbase
USERNAME=benchbase_user
PASSWORD=benchbase_pass

# 备节点连接信息（用于读分离测试）
STANDBY_HOST_1=192.168.1.11
STANDBY_HOST_2=192.168.1.12
```

## 基准测试配置

### 支持的基准测试类型

#### 1. TPC-C (在线事务处理)
- **适用场景**: 评估OLTP性能
- **特点**: 高并发事务处理
- **测试内容**: 订单管理、库存更新、支付处理

#### 2. TPC-H (决策支持)
- **适用场景**: 评估OLAP性能
- **特点**: 复杂分析查询
- **测试内容**: 数据仓库查询、聚合计算

#### 3. YCSB (云服务基准)
- **适用场景**: 评估NoSQL风格工作负载
- **特点**: 键值操作
- **测试内容**: 读写比例可调

#### 4. SmallBank (简单银行)
- **适用场景**: 评估简单事务性能
- **特点**: 轻量级OLTP
- **测试内容**: 银行转账、余额查询

### 配置文件模板

#### TPC-C配置示例
```xml
<?xml version="1.0"?>
<parameters>
    <dbtype>postgres</dbtype>
    <driver>org.postgresql.Driver</driver>
    <url>jdbc:postgresql://192.168.1.10:5432/benchbase</url>
    <username>benchbase_user</username>
    <password>benchbase_pass</password>
    
    <!-- 数据库连接池配置 -->
    <isolation>TRANSACTION_READ_COMMITTED</isolation>
    <batchsize>128</batchsize>
    
    <!-- 工作负载配置 -->
    <scalefactor>10</scalefactor>
    <terminals>64</terminals>
    <works>
        <work>
            <time>300</time>
            <rate>unlimited</rate>
            <weights>45,43,4,4,4</weights>
        </work>
    </works>
    
    <!-- TPC-C特定配置 -->
    <transactiontypes>
        <transactiontype>
            <name>NewOrder</name>
        </transactiontype>
        <transactiontype>
            <name>Payment</name>
        </transactiontype>
        <transactiontype>
            <name>OrderStatus</name>
        </transactiontype>
        <transactiontype>
            <name>Delivery</name>
        </transactiontype>
        <transactiontype>
            <name>StockLevel</name>
        </transactiontype>
    </transactiontypes>
</parameters>
```

#### 读写分离配置
```xml
<!-- 主节点用于写操作 -->
<write_url>jdbc:postgresql://192.168.1.10:5432/benchbase</write_url>

<!-- 备节点用于读操作 -->
<read_urls>
    <url>jdbc:postgresql://192.168.1.11:5432/benchbase</url>
    <url>jdbc:postgresql://192.168.1.12:5432/benchbase</url>
</read_urls>
```

## 执行测试

### 1. 数据库初始化

```bash
# 创建数据库表结构
java -jar benchbase.jar -b tpcc -c config/tpcc_opengauss.xml --create=true

# 加载测试数据
java -jar benchbase.jar -b tpcc -c config/tpcc_opengauss.xml --load=true
```

### 2. 执行基准测试

```bash
# 执行完整的TPC-C测试
java -jar benchbase.jar -b tpcc -c config/tpcc_opengauss.xml --execute=true

# 执行其他基准测试
java -jar benchbase.jar -b tpch -c config/tpch_opengauss.xml --execute=true
java -jar benchbase.jar -b ycsb -c config/ycsb_opengauss.xml --execute=true
java -jar benchbase.jar -b smallbank -c config/smallbank_opengauss.xml --execute=true
```

### 3. 批量测试脚本

```bash
#!/bin/bash
# 批量执行多种基准测试

BENCHMARKS=("tpcc" "tpch" "ycsb" "smallbank")
RESULTS_DIR="./results/$(date +%Y%m%d_%H%M%S)"

mkdir -p $RESULTS_DIR

for benchmark in "${BENCHMARKS[@]}"; do
    echo "执行 $benchmark 基准测试..."
    java -jar benchbase.jar \
        -b $benchmark \
        -c config/${benchmark}_opengauss.xml \
        --execute=true \
        -d $RESULTS_DIR/${benchmark}
done
```

## 结果分析

### 关键性能指标

#### 1. 吞吐量指标
- **TPS (Transactions Per Second)**: 每秒事务数
- **QPS (Queries Per Second)**: 每秒查询数
- **NewOrder TPS**: TPC-C新订单事务率

#### 2. 延迟指标
- **平均延迟**: 事务平均响应时间
- **P95延迟**: 95%事务的响应时间
- **P99延迟**: 99%事务的响应时间
- **最大延迟**: 最长响应时间

#### 3. 资源利用率
- **CPU使用率**: 各节点CPU使用情况
- **内存使用率**: 数据库内存占用
- **磁盘I/O**: 读写IOPS和吞吐量
- **网络I/O**: 网络流量和延迟

### 结果文件解析

```bash
# 结果目录结构
results/
├── summary.json          # 测试摘要
├── histogram.json         # 延迟分布直方图
├── transactions.csv       # 详细事务记录
└── system_metrics.log     # 系统资源监控
```

### 性能分析工具

#### 1. 自动化分析脚本
```python
import json
import pandas as pd
import matplotlib.pyplot as plt

def analyze_benchbase_results(results_dir):
    # 读取测试结果
    with open(f"{results_dir}/summary.json") as f:
        summary = json.load(f)
    
    # 分析吞吐量
    throughput = summary["Throughput(req/sec)"]
    print(f"平均吞吐量: {throughput} TPS")
    
    # 分析延迟
    latency_data = summary["Latency Distribution"]
    print(f"P95延迟: {latency_data['95th']} ms")
    print(f"P99延迟: {latency_data['99th']} ms")
```

## 高级配置

### 1. 连接池优化

```xml
<!-- 连接池配置 -->
<connection_pool>
    <initial_size>10</initial_size>
    <max_size>100</max_size>
    <min_idle>5</min_idle>
    <max_idle>20</max_idle>
    <max_wait>30000</max_wait>
</connection_pool>
```

### 2. 负载均衡策略

```xml
<!-- 读写分离负载均衡 -->
<load_balancing>
    <strategy>round_robin</strategy>  <!-- 轮询 -->
    <read_weight>
        <node1>30</node1>
        <node2>70</node2>
    </read_weight>
</load_balancing>
```

### 3. 故障转移配置

```xml
<!-- 故障转移设置 -->
<failover>
    <enabled>true</enabled>
    <timeout>5000</timeout>
    <retry_attempts>3</retry_attempts>
</failover>
```

### 4. 监控集成

```xml
<!-- 集成监控系统 -->
<monitoring>
    <prometheus>
        <enabled>true</enabled>
        <port>9090</port>
    </prometheus>
    <grafana>
        <dashboard_url>http://localhost:3000</dashboard_url>
    </grafana>
</monitoring>
```

## 测试场景设计

### 场景1: 基础性能测试
- **目标**: 评估单节点与多节点性能差异
- **配置**: 逐步增加节点数量
- **指标**: TPS、延迟、资源利用率

### 场景2: 读写分离测试
- **目标**: 评估读写分离效果
- **配置**: 不同读写比例(8:2, 9:1, 7:3)
- **指标**: 读吞吐量提升、写性能影响

### 场景3: 故障恢复测试
- **目标**: 评估高可用性
- **配置**: 模拟节点故障
- **指标**: 故障检测时间、恢复时间

### 场景4: 扩展性测试
- **目标**: 评估水平扩展能力
- **配置**: 2-8节点扩展测试
- **指标**: 线性扩展比率

## 故障排除

### 常见问题及解决方案

#### 1. 连接超时问题
```bash
# 症状: Connection timeout
# 解决方案:
- 检查网络连接
- 调整超时参数
- 检查防火墙设置
```

#### 2. 内存不足错误
```bash
# 症状: OutOfMemoryError
# 解决方案:
- 增加JVM堆内存: -Xmx8g
- 减少并发线程数
- 优化数据库连接池
```

#### 3. 数据不一致问题
```bash
# 症状: 主备数据不一致
# 解决方案:
- 检查同步延迟
- 调整一致性级别
- 重新初始化备节点
```

#### 4. 性能异常波动
```bash
# 症状: TPS大幅波动
# 解决方案:
- 检查系统资源
- 调整垃圾回收参数
- 优化数据库配置
```

### 调试工具

```bash
# 启用详细日志
java -Djava.util.logging.config.file=logging.properties \
     -jar benchbase.jar ...

# 监控JVM性能
jstat -gc -t [pid] 5s

# 监控数据库连接
netstat -an | grep :5432
```

## 最佳实践

### 1. 测试前准备
- [ ] 清理系统缓存
- [ ] 确保网络稳定
- [ ] 预热数据库
- [ ] 校准时钟同步

### 2. 测试执行
- [ ] 逐步增加负载
- [ ] 监控系统资源
- [ ] 记录异常事件
- [ ] 保存详细日志

### 3. 结果分析
- [ ] 多次测试取平均值
- [ ] 分析异常数据点
- [ ] 对比基线性能
- [ ] 生成测试报告

## 参考资料

- [openGauss官方文档](https://docs.opengauss.org/)
- [BenchBase GitHub仓库](https://github.com/cmu-db/benchbase)
- [TPC-C基准测试标准](http://tpc.org/tpcc/)
- [PostgreSQL JDBC驱动文档](https://jdbc.postgresql.org/documentation/head/)

## 联系信息

如有技术问题或建议，请通过以下方式联系：
- 项目仓库: https://github.com/XCG0/HIT-HATM
- 技术讨论: 提交Issue到项目仓库

---
*最后更新时间: 2025年11月20日*