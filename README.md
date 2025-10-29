# openGuass 使用说明

## 宿主机相关准备

1. [安装 docker](https://blog.csdn.net/Cike___/article/details/146415836)，每次连接 docker 容器前**务必确保 Docker Desktop 已启动**。
    ![Docker Desktop](images/image-5.png)

2. 安装 [VS Code](https://code.visualstudio.com/)，并安装相关插件：
    ![远程连接相关插件](images/image-4.png)
    > 具体使用方法参考：[在 VS Code 中使用 docker](https://zhuanlan.zhihu.com/p/496213879)。

## 使用方法

### 创建 Docker 容器

1. 在宿主机上拉取镜像

    ```bash
    # 使用 Windows 版本
    docker pull xcg0/opengauss-openeuler_22.03_x86:v1.0

    # 使用 macOS 版本
    docker pull xcg0/opengauss-openeuler_22.03_aarch64:v1.0
    ```

2. 在宿主机上启动容器（注意替换 `--name` 与 `--hostname` 参数）

    ```bash
    # 使用 Windows PowerShell 创建
    docker run -itd --name opengauss-node0 `
      --hostname node0 `
      --privileged=true `
      -p 127.0.0.1:5432:5432 `
      xcg0/opengauss-openeuler_22.03_x86:v1.0 /bin/bash
    
    # 使用 macOS 创建
    docker run -itd --name opengauss-node0 \
      --hostname node0 \
      --privileged=true \
      -p 127.0.0.1:5432:5432 \
      xcg0/opengauss-openeuler_22.03-aarch64:v1.0 /bin/bash
    ```

3. 使用 VS Code 连接容器，进入 `\home` 目录。
    
    ![VSCode 连接容器 1](images/image-1.png)
    ![VSCode 连接容器 2](images/image-2.png)
    > 在容器中的 root 用户下运行 `code ‘文件夹路径或文件路径’` 可以直接在 VSCode 中打开。

    从 gitee 仓库中拉取代码：

    ```shell
    cd /home
    git init
    git remote add origin https://gitee.com/XuChGu/HIT-HADB.git # 添加远程仓库
    git pull origin main
    git checkout -f main
    ```

    `\home` 目录结构（文件夹）如下，其中 **`\omm` 和 `\openGauss` 目录为数据库相关文件，由于体积较大，未包含在 Git 仓库中**：

    ```
    home
    ├── .vscode          # VS Code 编译配置文件
    ├── docs             # 组会演示文档 
    ├── images
    ├── openGauss
    │     ├──openGauss-server # openGauss 数据库
    │     └──binarylibs       # 第三方依赖库
    └── omm
        ├── data          # 数据库数据文件
        └── log           # 数据库日志文件
    ```

### 数据库启动

操作数据库时，**务必使用 `omm` 用户身份**（执行 `su omm` 切换用户）。


1. 启动数据库（单节点）

    ```bash
    gs_ctl start -D /home/omm/data -Z single_node -l /home/omm/log/opengauss.log
    ```

    > 正常启动输出如下：
    > 
    > ```
    > [2025-10-22 13:16:44.405][1532773][][gs_ctl]: gs_ctl started,datadir is /home/omm/data 
    > [2025-10-22 13:16:44.572][1532773][][gs_ctl]: waiting for server to start...
    > .
    > [2025-10-22 13:16:46.570][1532773][][gs_ctl]:  done
    > [2025-10-22 13:16:46.570][1532773][][gs_ctl]: server started (/home/omm/data)
    > ```


2. 查询数据库状态

    ```bash
    gs_ctl query -D /home/omm/data
    ```

    > 状态正常时输出如下：
    > 
    > ```
    > [2025-10-22 13:17:42.333][1533927][][gs_ctl]: gs_ctl query ,datadir is /home/omm/data 
    >  HA state:           
    >         local_role                     : Normal
    >         static_connections             : 0
    >         db_state                       : Normal
    >         detail_information             : Normal
    > 
    >  Senders info:       
    > No information 
    >  Receiver info:      
    > No information 
    > ```

3. 关闭数据库

    ```bash
    gs_ctl stop -D /home/omm/data
    ```

    > 正常关闭时输出如下：
    > 
    > ```
    > [2025-10-22 13:16:08.621][1531932][][gs_ctl]: gs_ctl stopped ,datadir is /home/omm/data 
    > waiting for server to shut down...... done
    > server stopped
    > ```

4. 使用 VSCode PostgreSQL 插件连接数据库：

    在 PostgreSQL 插件中创建连接，连接类型选择 `PostgreSQL`，填写连接信息，保存并连接。

    ![PostgreSQL 插件连接 openGauss](/images/image.png)

    > 需要先启动数据库 `gs_ctl start ……`，才能连接成功。

### C/C++ 简单调试

> 直接使用 GDB 调试可以参考：
> [使用 gdb 调试 openGauss5.0.0 入门篇](https://blog.csdn.net/qq_43893755/article/details/130682379)。

- GDB 常见命令参考：

  | 命令 | 说明 | VSCode 快捷键 |
  | :---: | :---: | :---: |
  | `-q ${executable_file}` | 启动 gdb 并加载可执行文件 | - |
  | `c` | 继续执行程序 | 继续（F5） |
  | `n` | 执行下一行代码，不进入函数 | 逐过程（F10） |
  | `s` | 执行下一行代码，进入函数 | 单步调试（F11） |
  | `finish` | 执行到当前函数返回 | 单步跳出（Shift+F11） |

  ![VSCode 调试](images/image-3.png)

- 其它命令参考：[Linux 下 gdb 调试与技巧整理](https://zhuanlan.zhihu.com/p/162164942)

  | 命令 | 说明 |
  | :---: | :---: |
  | `b 行号/函数名` | 在指定行号或函数处设置断点 | - |
  | `info breakpoints` | 查看所有断点信息 | - |
  | `delete 断点编号` | 删除指定断点 | - |
  | `watch 变量名` | 监视变量值的变化 | - |
  | `print 变量名` | 打印变量的当前值 | - |
  | `backtrace` | 查看函数调用栈 | - |
  | `quit` | 退出 GDB 调试 | - |
  
  VScode 中可以直接使用侧边栏调试功能。
