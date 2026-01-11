# 单节点部署

本文档介绍如何在 Docker 容器中部署单节点 openGauss 数据库，适合用于开发和测试环境。

## 创建 Docker 容器

1. 在宿主机上启动容器（注意替换 `--name` 与 `--hostname` 参数）：

   ```powershell
   # Windows PowerShell
   docker run -itd --name opengauss-node0 `
     --hostname node0 `
     --privileged=true `
     -p 127.0.0.1:5432:5432 `
     -v ${PWD}/init-container.sh:/init-container.sh:ro `
     xcg0/opengauss-openeuler_22.03:x86_64 `
     bash /init-container.sh

   # macOS / Linux
   docker run -itd --name opengauss-node0 \
     --hostname node0 \
     --privileged=true \
     -p 127.0.0.1:5432:5432 \
     -v $(pwd)/init-container.sh:/init-container.sh:ro \
     xcg0/opengauss-openeuler_22.03:x86_64 \
     bash /init-container.sh
   ```
2. 使用 VS Code 连接容器，进入 `\home` 目录。

   > **注意**：创建容器时会使用 [init-container.sh](../../init-container.sh) 脚本在 `\home` 初始化 Git 仓库并拉取代码。如果不想继续跟踪后续代码，请删除 `/home/.git` 目录。
   >

   ![VSCode 连接容器 1](../images/image-1.png)
   ![VSCode 连接容器 2](../images/image-2.png)

   > 在容器中的 root 用户下运行 `code ‘文件夹路径或文件路径’` 可以直接在 VSCode 中打开。
   >

   **项目目录结构**如下：

   ```
   HIT-HATM/
   ├── .vscode/                      # VS Code 配置文件
   │   ├── launch.json               # 调试配置
   │   └── tasks.json                # 任务配置
   ├── docs/                         # 文档目录
   ├── images/                       # 文档图片
   ├── scripts/                      # 部署脚本
   │   ├── init-container.sh         # 容器初始化脚本
   │   ├── multi-node.sh             # 多节点一键部署脚本
   │   ├── multi-node/               # 多节点集群脚本
   │   └── benchBase/                # BenchBase 性能测试
   ├── tools/                        # 工具脚本
   ├── openGauss/                    # openGauss 源码 (容器内)
   │   └── openGauss-server/         # 数据库源码
   │   ── binarylibs/               # 第三方依赖库
   └── README.md                     # 项目说明文档
   ```

   > **注意**：
   >
   > - `openGauss/` 目录大部分文件为数据库源码，Git 仓库未跟踪该目录下的全部文件。
   >

## 数据库启动

操作数据库时，**务必使用 `omm` 用户身份**（执行 `su omm` 切换用户）。

1. 启动数据库（单节点）

   ```bash
   gs_ctl start -D /home/omm/data -Z single_node -l /home/omm/log/opengauss.log
   ```
2. 查询数据库状态

   ```bash
   gs_ctl query -D /home/omm/data
   ```
3. 关闭数据库

   ```bash
   gs_ctl stop -D /home/omm/data
   ```
