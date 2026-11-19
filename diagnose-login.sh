#!/bin/bash
# 登录问题一键诊断脚本
# 运行方式：cd ~/project && bash diagnose-login.sh

set -e

PROJECT_DIR="${1:-$(pwd)}"
cd "$PROJECT_DIR"

echo "========== 1. 项目路径与文件 =========="
echo "当前目录: $(pwd)"
ls -la docker-compose-all.yml backend/.env db/init.sql 2>/dev/null || echo "缺少关键文件"

echo ""
echo "========== 2. 容器运行状态 =========="
docker compose -f docker-compose-all.yml ps

echo ""
echo "========== 3. 后端最近 30 行日志 =========="
docker logs --tail 30 fastapi-admin 2>&1 || echo "fastapi-admin 容器未运行/未找到"

echo ""
echo "========== 4. 前端最近 20 行日志 =========="
docker logs --tail 20 vue-front 2>&1 || echo "vue-front 容器未运行/未找到"

echo ""
echo "========== 5. 数据库用户表 =========="
docker exec -i mariadb-admin \
  mysql -uadmin_user -pAdmin@2026 admin_db \
  -e "SELECT id, username, LEFT(password,20) AS pw_preview FROM sys_user;" 2>&1 || echo "数据库查询失败"

echo ""
echo "========== 6. 服务器本地绕过浏览器测试登录 =========="
curl -s -X POST 'http://localhost:8080/api/login' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=admin&password=123456' \
  -w "\nHTTP状态码: %{http_code}\n" || echo "curl 测试失败"

echo ""
echo "========== 7. 服务器上直接连后端 8000 测试 =========="
curl -s -X POST 'http://localhost:8000/api/login' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=admin&password=123456' \
  -w "\nHTTP状态码: %{http_code}\n" || echo "curl 直连后端失败"

echo ""
echo "========== 8. Nginx 配置检查 =========="
docker exec -i vue-front cat /etc/nginx/conf.d/default.conf 2>/dev/null || docker exec -i vue-front cat /etc/nginx/nginx.conf 2>/dev/null || echo "无法读取 Nginx 配置"

echo ""
echo "========== 9. 后端 .env 内容 =========="
cat backend/.env 2>/dev/null || echo "backend/.env 不存在"

echo ""
echo "========== 10. 防火墙与安全组（本机侧） =========="
ufw status 2>/dev/null || echo "ufw 未启用/未安装"
echo "监听端口:"
ss -tlnp 2>/dev/null | grep -E '8080|8000|3306|80' || netstat -tlnp 2>/dev/null | grep -E '8080|8000|3306|80' || echo "未找到 ss/netstat"

echo ""
echo "========== 11. 公网 IP 自测 =========="
curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "无法获取公网 IP"

echo ""
echo "========== 诊断完成，请复制以上全部输出 =========="
