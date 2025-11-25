# 镜像构建与上传

本文档介绍如何基于已有的 openGauss Docker 容器构建镜像，并上传到 Docker hub 以便共享和分发。

## 扁平化镜像

Docker 镜像是分层的，删除操作只是在新的一层标记文件为“已删除”，
原始文件仍然存在于之前的层中，占用空间。

`docker commit` 会保留所有历史层，打包的镜像体积较大，可以通过以下步骤清理容器内不必要的文件，生成扁平化镜像，从而减小镜像体积，提高上传速度：

- 容器内执行：

    ```shell
    # 在容器内停止数据库
    su - omm
    gs_ctl stop -D /home/omm/data

    cd /home
    bash cleanup.sh
    ```
- 在宿主机执行：

    ```shell
    # 1. 导出容器为 tar 文件（）
    docker export opengauss-node0 > opengauss-clean.tar

    # 2. 导入为新镜像
    cat opengauss-clean.tar | docker import \
      --change 'CMD ["/bin/bash"]' \
      --change 'WORKDIR /home' \
      --change 'ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
      - xcg0/opengauss-openeuler_22.03:x86_64

    # 3. 推送新镜像
    docker login
    docker push xcg0/opengauss-openeuler_22.03:x86_64

    # 4. 清理临时文件
    rm opengauss-clean.tar
    ```

> 创建容器时自动执行脚本 [init-container.sh](../../init-container.sh)，会拉取最新的镜像配置仓库并初始化数据库环境，建议定期更新镜像（`git pull`）以获取最新的代码和配置。
>
> ```powershell
>    # Windows PowerShell
>    docker run -itd --name opengauss-node0 `
>      --hostname node0 `
>      --privileged=true `
>      -p 127.0.0.1:5432:5432 `
>      -v ${PWD}/init-container.sh:/init-container.sh:ro `
>      xcg0/opengauss-openeuler_22.03:x86_64 `
>      bash /init-container.sh
>
>    # macOS / Linux
>    docker run -itd --name opengauss-node0 \
>      --hostname node0 \
>      --privileged=true \
>      -p 127.0.0.1:5432:5432 \
>      -v $(pwd)/init-container.sh:/init-container.sh:ro \
>      xcg0/opengauss-openeuler_22.03:aarch64 \
>      bash /init-container.sh
>    ```

## 构建镜像并上传 Docker hub

> 参考：[将自己的 docker 镜像推送到 docker hub](https://blog.csdn.net/weixin_44649780/article/details/135107176)

1. 打包镜像 `docker commit <容器名或id> <镜像名>:<标签（可选）>`

    ```shell
    # openEuler - 从正在运行的容器创建镜像
    docker commit opengauss-node0 xcg0/opengauss-openeuler_22.03-lts:v1.0

    # centos - 从正在运行的容器创建镜像
    docker commit opengauss-node1 xcg0/opengauss-centos_7.6.1810:v1.0
    ```

2. 登录 Docker hub，将镜像上传 `docker push <dockerhub用户名>/<仓库名>:<标签（可选）>`

    ![Docker hub 仓库](../../images/image-6.png)

    ```shell
    # 登录 Docker Hub（会提示输入用户名和密码）
    docker login
    
    # 推送 centos 镜像
    docker push xcg0/opengauss-centos_7.6.1810:v1.0
    
    # 推送 openEuler 镜像
    docker push xcg0/opengauss-openeuler_22.03-lts:v1.0
    ```

3. 升级仓库镜像

    ```shell
    docker login

    # 重新打包镜像
    docker commit <镜像名> <容器名或id> <镜像名>:v1.1

    # 推送新版本镜像
    docker push <dockerhub用户名>/<仓库名>:v1.1
    ```