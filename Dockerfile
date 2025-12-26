# 使用官方Python运行时作为基础镜像
FROM python:3.10-alpine

# 设置工作目录
WORKDIR /app

# 复制项目依赖文件
COPY requirements.txt .

# 安装依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制项目文件
COPY . .

# 暴露端口
EXPOSE 5000

# 运行应用
CMD ["python", "run.py"]