# openGauss 多节点集群 - Docker 容器创建脚本 (Windows PowerShell)
# 创建一主两备的集群环境

Write-Host "=== openGauss 多节点集群部署 ===" -ForegroundColor Green
Write-Host ""

# 检查镜像是否存在
$IMAGE_NAME = "xcg0/opengauss-openeuler_22.03:x86_64"
Write-Host "检查镜像: $IMAGE_NAME" -ForegroundColor Yellow
$imageExists = docker images -q $IMAGE_NAME
if (-not $imageExists) {
    Write-Host "错误: 镜像 $IMAGE_NAME 不存在，请先拉取镜像" -ForegroundColor Red
    Write-Host "运行: docker pull $IMAGE_NAME" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ 镜像已存在" -ForegroundColor Green
Write-Host ""

# 停止并删除已存在的容器（如果有）
Write-Host "清理已存在的容器..." -ForegroundColor Yellow
$containers = @("opengauss-primary", "opengauss-standby1", "opengauss-standby2")
foreach ($container in $containers) {
    $exists = docker ps -a -q -f name=$container
    if ($exists) {
        Write-Host "  停止并删除容器: $container"
        docker stop $container 2>$null
        docker rm $container 2>$null
    }
}
Write-Host "✓ 清理完成" -ForegroundColor Green
Write-Host ""

# 删除已存在的网络（如果有）
Write-Host "检查 Docker 网络..." -ForegroundColor Yellow
$networkExists = docker network ls -q -f name=opengauss-network
if ($networkExists) {
    Write-Host "  删除已存在的网络: opengauss-network"
    docker network rm opengauss-network 2>$null
}

# 创建自定义网络
Write-Host "创建 Docker 网络: opengauss-network (172.18.0.0/16)" -ForegroundColor Yellow
docker network create `
    --driver bridge `
    --subnet=172.18.0.0/16 `
    --gateway=172.18.0.1 `
    opengauss-network

if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: 创建网络失败" -ForegroundColor Red
    exit 1
}
Write-Host "✓ 网络创建成功" -ForegroundColor Green
Write-Host ""

# 创建主节点
Write-Host "创建主节点容器: opengauss-primary (172.18.0.10)" -ForegroundColor Yellow
docker run -itd `
    --name opengauss-primary `
    --hostname primary `
    --network opengauss-network `
    --ip 172.18.0.10 `
    --privileged=true `
    -p 127.0.0.1:15432:5432 `
    $IMAGE_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: 创建主节点失败" -ForegroundColor Red
    exit 1
}
Write-Host "✓ 主节点创建成功" -ForegroundColor Green
Write-Host ""

# 创建备节点1
Write-Host "创建备节点1容器: opengauss-standby1 (172.18.0.11)" -ForegroundColor Yellow
docker run -itd `
    --name opengauss-standby1 `
    --hostname standby1 `
    --network opengauss-network `
    --ip 172.18.0.11 `
    --privileged=true `
    -p 127.0.0.1:15433:5432 `
    $IMAGE_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: 创建备节点1失败" -ForegroundColor Red
    exit 1
}
Write-Host "✓ 备节点1创建成功" -ForegroundColor Green
Write-Host ""

# 创建备节点2
Write-Host "创建备节点2容器: opengauss-standby2 (172.18.0.12)" -ForegroundColor Yellow
docker run -itd `
    --name opengauss-standby2 `
    --hostname standby2 `
    --network opengauss-network `
    --ip 172.18.0.12 `
    --privileged=true `
    -p 127.0.0.1:15434:5432 `
    $IMAGE_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: 创建备节点2失败" -ForegroundColor Red
    exit 1
}
Write-Host "✓ 备节点2创建成功" -ForegroundColor Green
Write-Host ""

# 验证容器状态
Write-Host "=== 容器状态 ===" -ForegroundColor Green
docker ps -f "name=opengauss-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Host ""

# 验证网络配置
Write-Host "=== 网络配置 ===" -ForegroundColor Green
docker network inspect opengauss-network --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
Write-Host ""

Write-Host "=== 部署成功 ===" -ForegroundColor Green
Write-Host "下一步: 配置 SSH 互信" -ForegroundColor Yellow
Write-Host "运行: docker exec -it opengauss-primary bash" -ForegroundColor Cyan
Write-Host "然后在容器内运行: cd /home/scripts && bash 02_setup_ssh.sh" -ForegroundColor Cyan
