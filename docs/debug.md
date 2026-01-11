# openGauss 数据库内核调试指南

本文档介绍如何验证 openGauss 数据库是否以调试模式编译，以及如何在 VS Code 中进行数据库内核源码级调试。

## 验证 openGauss 调试模式编译

验证数据库是否以调试模式编译，确保可以使用 GDB 进行源码级调试。

> 验证结果
>
> ✅ 如果以下检查都通过，说明：
>
> - 编译时已启用调试模式
> - 二进制文件包含完整的 DWARF 调试符号
> - 可以使用 GDB 进行源码级调试、设置断点、查看变量等
>
> ⚠️ **注意：** 调试版本的可执行文件体积较大，生产环境可使用 `strip` 命令移除调试符号以减小体积。

### 1. 检查编译配置

```bash
# 查看 Makefile 中的调试配置
grep -E "^enable_debug|^enable_cassert" /home/openGauss/openGauss-server/src/Makefile.global
```

**期望输出：**

```
enable_cassert  = yes
enable_debug    = yes
```

### 2. 验证二进制文件包含调试信息

```bash
# 检查可执行文件类型
file /home/openGauss/openGauss-server/mppdb_temp_install/bin/gaussdb
```

**关键标志：**

- `with debug_info` - 包含调试信息
- `not stripped` - 未剥离符号表

### 3. 检查 DWARF 调试段

```bash
# 查看 ELF 文件中的调试段
readelf -S /home/openGauss/openGauss-server/mppdb_temp_install/bin/gaussdb | grep "\.debug_"
```

**应包含的调试段：**

- `.debug_info` - 核心调试信息（变量、函数等）
- `.debug_line` - 源代码行号映射
- `.debug_str` - 调试字符串
- `.debug_abbrev` - 调试信息缩写表
- `.debug_aranges` - 地址范围信息
- `.debug_loc` - 位置列表
- `.debug_ranges` - 地址范围
- `.debug_macro` - 宏定义信息

## 在 VS Code 中调试 openGauss 数据库内核

### 调试配置

已为工作区添加了调试配置（见 [launch.json](../../.vscode/launch.json)）：

| 配置名称                                  | 用途                  | 使用场景                     |
| ----------------------------------------- | --------------------- | ---------------------------- |
| **编译+调试客户端程序**             | 调试 libpq 客户端程序 | 调试自己编写的数据库应用程序 |
| **附加到 gaussdb 进程（内核调试）** | 附加到运行中的进程    | 调试数据库内核               |

### 快速开始

1. **启动数据库**

   ```bash
   su - omm
   gs_ctl start -D /home/omm/data -Z single_node -l /home/omm/log/opengauss.log
   ```
2. **在 VS Code 中启动调试**

- 按 `F5` 选择"附加到 gaussdb 进程（内核调试）"
- 在进程列表中选择目标进程（这一步可能需要十几秒左右加载进程列表）
- 设置断点并执行 SQL 触发

  ![在 VS Code 中启动调试](../images/image-7.png)

### 常用调试场景

> 可以点击链接跳转到断点所对应的代码位置。

| 场景                      | 关键断点                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | 调试目标                     | 示例 SQL                                                         |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | ---------------------------------------------------------------- |
| **1. 查询执行流程** | [`exec_simple_query()`](../../openGauss/openGauss-server/src/gausskernel/process/tcop/postgres.cpp#L2369)`<br>`[`pg_parse_query()`](../../openGauss/openGauss-server/src/gausskernel/process/tcop/postgres.cpp#L1010)`<br>`[`pg_plan_queries()`](../../openGauss/openGauss-server/src/gausskernel/process/tcop/postgres.cpp#L1485)`<br>`[`ExecutorRun()`](../../openGauss/openGauss-server/src/gausskernel/runtime/executor/execMain.cpp#L444)                                             | SQL 解析→优化→执行完整流程 | `INSERT INTO test VALUES (1, 'x');<br>``SELECT * FROM test;` |
| **2. 事务和 MVCC**  | [`StartTransaction()`](../../openGauss/openGauss-server/src/gausskernel/storage/access/transam/xact.cpp#L2307)`<br>`[`GetTransactionSnapshot()`](../../openGauss/openGauss-server/src/common/backend/utils/time/snapmgr.cpp#L479)`<br>`[`HeapTupleSatisfiesMVCC()`](../../openGauss/openGauss-server/src/gausskernel/storage/access/heap/heapam_visibility.cpp#L1026)`<br>`[`CommitTransaction()`](../../openGauss/openGauss-server/src/gausskernel/storage/access/transam/xact.cpp#L2583) | 快照隔离、可见性判断         | 两会话并发读写同一行                                             |
| **3. 锁机制**       | [`LockAcquire()`](../../openGauss/openGauss-server/src/gausskernel/storage/lmgr/lock.cpp#L533)`<br>`[`LockRelease()`](../../openGauss/openGauss-server/src/gausskernel/storage/lmgr/lock.cpp#L1860)`<br>`[`DeadLockCheck()`](../../openGauss/openGauss-server/src/gausskernel/storage/lmgr/deadlock.cpp#L191)`<br>`[`ProcSleep()`](../../openGauss/openGauss-server/src/gausskernel/storage/lmgr/proc.cpp#L1748)                                                                           | 锁冲突、死锁检测             | 两会话交叉更新不同行                                             |
| **4. 缓冲区管理**   | [`ReadBuffer()`](../../openGauss/openGauss-server/src/gausskernel/storage/buffer/bufmgr.cpp#L1632)`<br>`[`BufferAlloc()`](../../openGauss/openGauss-server/src/gausskernel/storage/buffer/bufmgr.cpp#L354)`<br>`[`FlushBuffer()`](../../openGauss/openGauss-server/src/gausskernel/storage/buffer/bufmgr.cpp#L4664)`<br>`[`StrategyGetBuffer()`](../../openGauss/openGauss-server/src/gausskernel/storage/buffer/freelist.cpp#L180)                                                        | 页面读取、缓冲区替换策略     | 大表全表扫描                                                     |
| **5. 索引操作**     | [`_bt_search()`](../../openGauss/openGauss-server/src/gausskernel/storage/access/nbtree/nbtsearch.cpp#L60)`<br>`[`_bt_split()`](../../openGauss/openGauss-server/src/gausskernel/storage/access/nbtree/nbtinsert.cpp#L74)                                                                                                                                                                                                                                                                    | B-Tree 查找/分裂             | `CREATE INDEX<br>`索引查询                                     |
| **6. WAL 和恢复**   | [`XLogInsert()`](../../openGauss/openGauss-server/src/gausskernel/storage/access/transam/xloginsert.cpp#L505)`<br>`[`StartupXLOG()`](../../openGauss/openGauss-server/src/gausskernel/storage/access/transam/xlog.cpp#L8741)                                                                                                                                                                                                                                                                 | 日志写入、崩溃恢复           | 模拟崩溃后重启                                                   |
| **7. 并发控制**     | [`heap_hot_search()`](../../openGauss/openGauss-server/src/gausskernel/storage/access/heap/heapam.cpp#L2600)`<br>`[`heap_page_prune()`](../../openGauss/openGauss-server/src/gausskernel/storage/access/heap/pruneheap.cpp#L173)`<br>`[`vacuum_rel()`](../../openGauss/openGauss-server/src/gausskernel/optimizer/commands/vacuum.cpp#L130)                                                                                                                                                 | HOT 更新、页面清理           | 频繁更新同一页数据                                               |
| **8. 优化器决策**   | [`planner()`](../../openGauss/openGauss-server/src/gausskernel/optimizer/plan/planner.cpp#L370)`<br>`[`create_plan()`](../../openGauss/openGauss-server/src/gausskernel/optimizer/plan/createplan.cpp#L302)`<br>`[`cost_seqscan()`](../../openGauss/openGauss-server/src/gausskernel/optimizer/path/costsize.cpp#L640)`<br>`[`cost_index()`](../../openGauss/openGauss-server/src/gausskernel/optimizer/path/costsize.cpp#L976)                                                            | 执行计划生成、代价估算       | `EXPLAIN` 对比不同查询计划                                     |
| **9. 内存管理**     | [`MemoryContextReset()`](../../openGauss/openGauss-server/src/common/backend/utils/mmgr/mcxt.cpp#L215)`<br>`[`MemoryContextDelete()`](../../openGauss/openGauss-server/src/common/backend/utils/mmgr/mcxt.cpp#L364)                                                                                                                                                                                                                                                                          | 内存分配与释放               | 执行复杂查询观察内存                                             |
| **10. 扩展功能**    | [`ExecCallTriggerFunc()`](../../openGauss/openGauss-server/src/gausskernel/optimizer/commands/trigger.cpp#L96)`<br>`[`exec_stmt_execsql()`](../../openGauss/openGauss-server/src/common/pl/plpgsql/src/pl_exec.cpp#L144)`<br>`[`fmgr_info()`](../../openGauss/openGauss-server/src/common/backend/utils/fmgr/fmgr.cpp#L246)                                                                                                                                                                 | 触发器、存储过程执行         | 创建并触发触发器                                                 |

### 查询执行流程调试示例

以 `exec_simple_query` 断点为例。监视变量：

1. `query_string`：当前执行的 SQL 语句
2. `parsetree_list`：解析后的语法树列表
3. `dest`：结果发送目标

完整命令流程，[详细说明](./exec_simple_query.md)：

| 序号 | 终端1 (GDB) | 终端2 (gsql) |                  命令                  | 简单说明                          |
| ---: | :---------: | :----------: | :------------------------------------: | :-------------------------------- |
|    1 |     🔴     |    &nbsp;    |            `gdb -p 1148`            | 附加到主进程(PID 从 4.2 步骤获得) |
|    2 |     🔴     |    &nbsp;    | `handle SIGUSR1 nostop noprint pass` | 忽略 SIGUSR1 信号(避免调试中断)   |
|    3 |     🔴     |    &nbsp;    |      `break exec_simple_query`      | 在 SQL 执行入口函数设置断点       |
|    4 |     🔴     |    &nbsp;    |              `continue`              | 继续执行,等待断点触发             |
|    5 |   &nbsp;   |      🟡      |          `gsql -d postgres`          | 连接到 postgres 数据库            |
|    6 |   &nbsp;   |      🟡      |             `SELECT 1;`             | 执行 SQL(触发 GDB 断点)           |
|    7 |     🔴     |    &nbsp;    |                `list`                | 显示当前断点处的源代码            |
|    8 |     🔴     |    &nbsp;    |         `print query_string`         | 打印当前执行的 SQL 语句           |
|    9 |     🔴     |    &nbsp;    |             `backtrace`             | 显示完整调用栈(函数调用链)        |
|   10 |     🔴     |    &nbsp;    |                `next`                | 单步执行(跳过函数)                |
|   11 |     🔴     |    &nbsp;    |                `step`                | 单步进入函数内部                  |
|   12 |     🔴     |    &nbsp;    |            `info locals`            | 显示所有局部变量                  |
|   13 |     🔴     |    &nbsp;    |              `continue`              | 继续执行到下一个断点或结束        |
|   14 |   &nbsp;   |      🟡      |          (查看 SQL 执行结果)          | 终端显示查询结果:`?column? = 1` |
|   15 |     🔴     |    &nbsp;    |           `quit` → `y`           | 退出 GDB,选择 `y` 确认分离进程  |
|   16 |   &nbsp;   |      🟡      |                 `\q`                 | 退出 gsql 客户端                  |

> 注意终端返回了执行结果后再执行下一条命令，没返回结果继续 `continue` 即可。
>
> VS Code 调试界面中也可以完成上述 GDB 命令操作，终端 1 可以使用 VS Code 调试界面，终端 2 使用 VS Code 内置终端即可。
>
> ![VS Code 调试 exec_simple_query](../images/image-8.png)
