## 一、TPC-C 一致性校验模型的作用

> TPC-C 的一致性校验模型，用来**验证数据库在高并发事务下是否真正保持了业务层面的数据一致性**，而不仅仅是“事务提交成功”。

TPC-C 模拟的是一个 **OLTP 订单系统**（仓库、订单、库存、客户、支付），即使所有 SQL 都成功执行，如果**业务数据之间的约束关系被破坏**，那这个数据库也是不合格的。

| 事务类型                    | 占比    | 主要业务含义       | 90% 响应时间要求 |
| --------------------------- | ------- | ------------------ | ---------------- |
| **New-Order（下单）**       | **45%** | 创建订单、扣库存   | ≤ 5 秒           |
| **Payment（支付）**         | **43%** | 客户付款、更新账目 | ≤ 5 秒           |
| **Order-Status（查订单）**  | **4%**  | 查询最近订单       | ≤ 5 秒           |
| **Delivery（发货）**        | **4%**  | 批量发货           | ≤ 5 秒           |
| **Stock-Level（库存检查）** | **4%**  | 查询低库存         | ≤ 20 秒          |

TPC-C 不只看 TPS，还要看：**结果是不是“对的”。**

```
TPS = 每秒成功提交的 New-Order 事务数
# 超时事务 不计入 TPS。
# 官方名称 tpmC（transactions per minute C）
TPS = tpmC ÷ 60

只要一致性校验失败，就认为tpmC = 0
```

### （1）订单（Orders / OrderLine / NewOrder）

**主要事务：**

- New-Order（45%）
- Order-Status（4%）
- Delivery（4%）

### （2）支付（Payment / History）

**主要事务：**

- Payment（43%）

### （3）库存（Stock）

**主要事务：**

- New-Order（45%）→ 扣库存
- Stock-Level（4%）→ 查库存

### （4）客户（Customer）

**主要事务：**

- Payment（43%）
- Order-Status（4%）

### （5）仓库 & 地区（Warehouse / District）

**涉及事务：**

- New-Order
- Payment
- Delivery

------

## 二、TPC-C 一致性校验的核心思想

TPC-C 的一致性模型遵循 3 个核心原则：

### （1） 只校验**最终状态**

- 不关心事务执行过程
- 只在测试结束后，对数据库做一次或多次一致性检查

### （2）校验的是**业务不变量（Business Invariants）**

不是检查：

- 行数对不对
- 有没有死锁

而是检查：

- 金额是否能对得上
- 汇总字段是否等于明细之和
- 逻辑关系是否被破坏

### （3） 不依赖具体实现

- 不要求数据库必须用强一致、弱一致
- 但**最终结果必须满足业务规则**

------

## 三、TPC-C 涉及的主要数据模型

![Image](https://www.tpc.org/information/sessions/sigmod/img009.JPG)

![Image](https://yqintl.alicdn.com/ebd84c4245a6a60c11588d5dca5331271b767beb.png)

![Image](https://benchmarksql.readthedocs.io/en/latest/TPC-C_ERD.svg)

TPC-C 里核心表包括：

| 模块 | 关键表                        |
| ---- | ----------------------------- |
| 仓库 | WAREHOUSE                     |
| 地区 | DISTRICT                      |
| 客户 | CUSTOMER                      |
| 订单 | ORDERS、NEW_ORDER、ORDER_LINE |
| 库存 | STOCK                         |
| 历史 | HISTORY                       |

一致性校验主要围绕这些表展开。

## 四、TPC-C 的初始化

必须遵守完全相同的数据生成规则（Data Population Rules）

| 参数                      | 说明             |
| ------------------------- | ---------------- |
| W（Warehouses）           | 仓库数量         |
| 每仓库 District 数        | 固定为 10        |
| 每 District Customer 数   | 固定为 3000      |
| 每 District 初始 Order 数 | 固定为 3000      |
| 每 Order 的 OrderLine 数  | 5–15（规则一致） |

### （1）数据分布规则（必须一致）

TPC-C 明确规定了字段的**生成方式**，比如：

- 客户姓氏用 **NURand()**
- 金额字段的取值范围
- 热点访问分布
- 本地 / 远程仓库比例（90% / 10%）

 **即使具体值不同，统计分布必须一致**

### （2）ORDERS / NEW_ORDER 的初始拆分

TPC-C 规定：

- 每个 District 最后 **900 个订单是未发货订单**
- 即：
  - 前 2100 个订单 → ORDERS + ORDER_LINE
  - 后 900 个订单 → ORDERS + ORDER_LINE + NEW_ORDER

📌 **是哪 900 个具体订单号是确定的（2101–3000）**
 但订单行内容是随机的。

### （3） 事务执行顺序：**不一致（必须随机）**

TPC-C **明确要求**：

> 各个终端（terminal / virtual user）
>  **独立、并发、随机地选择下一个事务类型**

**不同测试跑出来的事务时序一定不一样**

#### 单个事务内部：SQL 顺序是“固定的”

### ✔ 单个事务内部

以 **New-Order** 为例：

1. 读 DISTRICT（D_NEXT_O_ID）
2. 更新 DISTRICT
3. 插 ORDERS
4. 插 NEW_ORDER
5. 循环处理 ORDER_LINE
6. 更新 STOCK

 **这个 SQL 执行顺序是严格规定的**

## 五、TPC-C 官方规定的“一致性校验规则”

TPC-C 标准里**明确规定了一组必须通过的校验规则**，下面是重点规则的**逐条拆解**。

------

### 规则 1：WAREHOUSE 与 DISTRICT 的金额一致性

**规则描述：**

```text
For each warehouse:
W_YTD = SUM(D_YTD) for all districts in the warehouse
```

**含义：**

- 仓库年累计收入 = 该仓库下所有地区年累计收入之和

**校验 SQL 示例：**

```sql
SELECT
  w_id,
  w_ytd,
  SUM(d_ytd)
FROM warehouse w
JOIN district d ON d.d_w_id = w.w_id
GROUP BY w_id, w_ytd;
```

**失败说明什么？**

- 支付事务（Payment）更新不一致
- 丢更新 / 并发覆盖

------

### 规则 2：DISTRICT 与 ORDER 的订单编号一致性

**规则描述：**

```text
D_NEXT_O_ID - 1 = MAX(O_ID)
```

**含义：**

- 地区下一个可用订单号，应等于当前最大订单号 + 1

**校验目的：**

- 验证 New-Order 事务的**原子性**
- 防止“订单号跳号”或“重复号”

------

### 规则 3：NEW_ORDER 表的数量一致性

**规则描述：**

```text
COUNT(NEW_ORDER) = SUM(D_NEXT_O_ID - 1 - last_delivered_o_id)
```

**直观理解：**

- NEW_ORDER 表中的订单数 = 尚未发货的订单数

**常见错误来源：**

- Delivery 事务删除 NEW_ORDER 失败
- 并发删除/插入不一致

------

### 规则 4：ORDER_LINE 金额与 ORDERS / CUSTOMER 一致

**规则描述：**

```text
SUM(OL_AMOUNT) = O_TOTAL_AMOUNT
```

并进一步影响：

```text
CUSTOMER.C_BALANCE
```

**校验重点：**

- 明细行金额之和必须等于订单总额
- 客户余额必须准确反映支付和订单

------

### 规则 5：STOCK 库存一致性

**规则描述（简化版）：**

```text
S_QUANTITY >= 0
```

以及：

- 销售数量与库存扣减一致
- 回补逻辑正确

**这里常暴露的问题：**

- 并发扣库存未加锁
- 非幂等重试导致库存多扣

------

## 六、一致性校验在 TPC-C 测试流程中的位置

TPC-C 标准测试流程是：

```
1. 数据加载
2. Warm-up
3. 正式压测（TPS统计）
4. 停止事务
5. 一致性校验（Consistency Check）
6. 报告结果
```

------

## 六、工程实现中如何做一致性校验？

### 常见实现方式

#### ✔ 方式一：独立校验脚本（最常见）

- 使用 SQL / Python / Java
- 离线扫描数据库
- 汇总 + 对比

#### ✔ 方式二：压测工具内置校验

- 比如 BenchmarkSQL、HammerDB
- 自动生成校验 SQL

#### ✔ 方式三：双账本校验（工程强化）

- 事务过程中维护 shadow counter
- 压测结束做交叉对账（TPC-C 标准外）

## 
