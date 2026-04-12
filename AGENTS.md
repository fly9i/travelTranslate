
# AGENT.md

## 通用规则

1. 始终使用中文思考/回复
2. 每次有代码修改都要提交 git commit 并使用合适的更改说明
3. 如果是远程仓库，确保 push
4. 不要在代码中硬编码 API Key、密码等敏感信息，一律从环境变量读取

## 端口管理

- 启动服务时如遇端口占用，不要杀掉已有进程
- 按顺序尝试备用端口（后端：8000 → 8001 → 8002，前端：5173 → 5174 → 5175）
- 成功启动后必须明确告知实际使用的端口号

## 工作区说明

1. 项目文档需要从以下路径读取:
   - docs/*.md
   - README.md
   - PROJECT.md
   - CHANGELOG.md
2. 项目文档使用中文
3. 依赖变更后必须执行 `uv sync`
4. 维护 `.env.example` 作为环境变量模板（不包含实际敏感值），与 `.env` 保持同步

## 技术栈

### 后端

- Python 3.12+
- uv 包管理/虚拟环境（在当前目录的 `.venv` 用于虚拟环境）
- FastAPI
- Uvicorn
- SQLite + Alembic（数据库迁移）
- .env 保存配置，使用 pydantic-settings 读取

### 前端

- Vue 3（Composition API + `<script setup>` 语法）
- Vite 构建工具
- TailwindCSS
- Pinia 状态管理（如需要）

## 代码风格

### Python

- 使用 ruff 进行 lint 和格式化
- 所有函数、方法必须添加 type hints
- 使用 Pydantic model 定义 API 的请求和响应结构
- 日志使用 `logging` 模块，禁止使用 `print` 调试

### 前端

- 使用 ESLint + Prettier 格式化
- 组件使用 `<script setup lang="ts">` 风格（如使用 TypeScript）
- 禁止使用 Options API

## 错误处理

- FastAPI 路由使用统一异常处理中间件
- 前端 API 调用统一封装，错误使用 `console.error` 记录，不静默吞掉
- 数据库操作使用 try/except 并记录日志

## 测试

- 新增 API 端点时同步编写 pytest 测试用例
- 测试文件放在 `tests/` 目录下，命名为 `test_<模块名>.py`
- 功能实现后使用 curl 或 httpie 进行基本验证

## 数据库

- 使用 Alembic 管理 schema 迁移
- 每次 schema 变更必须生成迁移脚本并提交
- 在 `docs/schema.md` 中维护数据模型文档

## Git 规范

- commit message 使用中文，格式：`<类型>: <简要描述>`
- 类型包括：功能、修复、重构、文档、配置、测试
- 示例：`功能: 添加用户登录接口`、`修复: 修复分页查询越界问题`
