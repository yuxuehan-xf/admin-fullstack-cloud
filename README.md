# admin-fullstack-cloud

Vue3 后台管理 + FastAPI + MariaDB + Nginx 的全栈教学项目，已容器化，支持**本地手动部署**、**本地 CI/CD 自动部署**，也可直接用于线上服务器部署。

## 技术栈

| 层 | 技术 | 说明 |
|---|---|---|
| 前端 | Vue3 + Vite + Element Plus + axios | 构建产物由 Nginx 托管，访问路径 `/admin/` |
| 后端 | FastAPI + PyMySQL + PyJWT + bcrypt | 接口文档 `/docs`，监听 8000 |
| 数据库 | MariaDB 10.6 | 初始化脚本 `db/init.sql` |
| 部署 | Docker + docker compose + Nginx | 编排文件 `docker-compose-all.yml` |
| 自动化 | GitHub Actions（self-hosted Runner） | `.github/workflows/` |

## 目录结构

```
admin-fullstack-cloud/
├── admin-vue/                     # Vue3 前端
│   ├── Dockerfile                 # 两阶段构建：node 构建 → nginx 托管
│   ├── nginx.conf                 # 容器内 nginx 配置（/admin、/api、/upload 转发）
│   ├── .env.production            # 生产环境变量（头像地址，需改成服务器 IP）
│   └── src/                       # 页面源码（Login / Layout / User / Upload）
├── backend/                       # FastAPI 后端
│   ├── Dockerfile
│   ├── requirements.txt           # Python 依赖
│   ├── .env                       # 真实环境变量（不提交）
│   ├── .env.example               # 环境变量模板（提交）
│   ├── .dockerignore
│   ├── seed_data.py               # 批量插入测试用户
│   └── app/                       # api / core / utils
├── db/init.sql                    # 建库建表 + 默认管理员
├── deploy/git-hooks/              # 离线部署用的 Git 钩子参考文件
├── .github/workflows/
│   ├── deploy-local.yml           # 本地虚拟机自动部署（self-hosted Runner）
│   └── deploy.yml                 # 线上服务器自动部署（self-hosted Runner）
├── docker-compose-all.yml         # 全栈编排（db + 后端 + 前端）
└── README.md
```

## 快速开始（任意装了 Docker 的 Linux 服务器）

```bash
# 1. 准备后端环境变量（容器内用服务名 db 访问数据库，不要写 IP）
cd backend
cp .env.example .env

# 2. 修改前端生产环境配置里的服务器 IP
cd ../admin-vue
nano .env.production        # VITE_AVATAR_URL=http://<服务器IP>:8000/upload/avatars

# 3. 构建并启动三个容器
cd ..
docker compose -f docker-compose-all.yml up -d --build

# 4. 查看状态
docker ps

# 5. 首次部署插入测试数据（幂等，可重复执行）
docker exec fastapi-admin python seed_data.py
```

访问地址：

| 入口 | 地址 |
|---|---|
| 前端页面 | `http://<服务器IP>:8080/admin/` |
| 后端接口文档 | `http://<服务器IP>:8000/docs` |
| MariaDB | `<服务器IP>:3306` |

默认账号：`admin` / `123456`；脚本导入或新增用户时默认密码也是 `123456`。

## 环境变量

| 文件 | 是否提交 | 作用 |
|---|---|---|
| `backend/.env` | ❌ 不提交（`.gitignore`） | 数据库连接、JWT 密钥、监听端口。每台服务器单独维护 |
| `backend/.env.example` | ✅ 提交 | 上面那份文件的模板 |
| `admin-vue/.env.production` | ✅ 提交 | 前端生产环境变量；`VITE_AVATAR_URL` 必须是部署服务器的 IP |

> `DB_HOST` 必须写 compose 服务名 `db`；写成 IP 会导致后端连不上数据库。

## 自动部署

两条流水线的原理相同：**push 代码 → Runner 在目标机器上重建容器**。

### 本地（`deploy-local.yml`）

1. 在虚拟机安装 self-hosted Runner，注册时带标签：`--labels local-vm`；
2. 部署目录固定为 `/home/ubuntu/admin-fullstack-cloud`（是仓库的 git 克隆）；
3. `git push` 到 `main` 分支即触发，构建日志在仓库 **Actions** 页面查看。

标签必须与工作流里的 `runs-on: [self-hosted, local-vm]` 完全一致，否则任务会一直排队。

### 线上（`deploy.yml`）

线上流水线假设部署目录为 `/root/project`，且服务器上的 Runner 使用默认标签 `self-hosted`：

```bash
# 线上服务器首次准备
mkdir -p /root/project && cd /root/project
git clone <你的仓库地址> .
cat > backend/.env <<'EOF'
DB_HOST=db
DB_PORT=3306
DB_USER=admin_user
DB_PASSWORD=Admin@2026
DB_NAME=admin_db
JWT_SECRET_KEY=admin_2026_secret_888
JWT_ALGORITHM=HS256
JWT_EXPIRE_HOUR=2
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
EOF
```

> 如果线上目录不是 `/root/project`，请同步修改 `deploy.yml` 里的路径。

## 数据库说明

- 表结构由 `db/init.sql` 创建，包含 `sys_user`（用户）和 `upload_file`（上传记录）；
- 该脚本**只在数据卷为空时执行一次**（MariaDB 官方镜像行为）。改了 `init.sql` 后要重建库：

```bash
docker compose -f docker-compose-all.yml down -v    # -v 会删除数据库数据卷，慎用
docker compose -f docker-compose-all.yml up -d --build
```

- 数据库数据存放在 `db_data` 数据卷中，不会随容器删除而丢失。

## 常见问题

| 现象 | 原因与解决 |
|---|---|
| 后端启动后报数据库连接失败 | `backend/.env` 缺失或 `DB_HOST` 写成了 IP；确认写的是 `db` |
| 容器 `Up` 但页面空白 / 404 | 前端未构建成功或 Nginx 路由问题；重新 `up -d --build` |
| 页面头像不显示 | `admin-vue/.env.production` 里的 IP 不是当前服务器 IP，改完重新构建 |
| 文件上传接口报错 | 数据库缺少 `upload_file` 表；`db/init.sql` 已包含，按上文重建库 |
| 拉取镜像超时 / 403 | 配置 Docker 镜像加速器后 `sudo systemctl restart docker` |
| 构建很慢 | 确认 `backend/.dockerignore` 存在（排除 `venv/`），首次构建需下载基础镜像 |
# admin-fullstack-cloud
