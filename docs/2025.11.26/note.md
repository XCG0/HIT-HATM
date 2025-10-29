# 工作总结

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
      - xcg0/opengauss-openeuler_22.03_x86:v1.0

    # 3. 推送新镜像
    docker login
    docker push xcg0/opengauss-openeuler_22.03_x86:v1.0

    # 4. 清理临时文件
    rm opengauss-clean.tar
    ```

## 在 Docker 容器中推送代码至 GitHub

git init
git remote add origin https://gitee.com/XuChGu/HIT-HADB.git
git pull origin main
git checkout -f main