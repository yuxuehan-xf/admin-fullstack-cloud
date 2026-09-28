FROM python:3.10
WORKDIR /root/backend

# 先装依赖（代码改动时这层可复用缓存，构建更快）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 再拷业务代码（venv、.env、upload 等已由 .dockerignore 排除）
COPY . .

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
