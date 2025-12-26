# Docker 部署说明

## 项目结构
- `Dockerfile`: 后端 Flask API 服务
- `Dockerfile.frontend`: 前端 Vue 应用
- `docker-compose.yml`: 协调前后端服务
- `nginx.conf`: Nginx 配置文件，用于前端静态文件服务和API代理

## 快速启动

### 使用 Docker Compose (推荐)
```bash
# 构建并启动服务
docker-compose up -d

# 访问应用
# 前端: http://localhost
# 后端API: http://localhost/api
```

### 单独构建镜像
```bash
# 构建后端镜像
docker build -t kube-yun-api .

# 构建前端镜像
docker build -f Dockerfile.frontend -t kube-yun-app .
```

## 端口映射
- 前端: 80 (HTTP)
- 后端: 5000 (Flask API)

## 数据持久化
- `.clusters.yaml`: 集群配置文件
- `.crypto.key`: 加密KEY
- `.kube`: kube配置文件
- `./logs`: 日志目录

## 环境变量
- `FLASK_ENV`: Flask环境 (默认: production)

## 注意事项
1. 首次运行时需要在前端配置Kubernetes集群信息
2. 集群配置文件会持久化存储，重启后配置依然存在
3. 如果需要修改前端配置，可以修改 `nginx.conf` 文件