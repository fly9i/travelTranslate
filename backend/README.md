# TravelTranslator 后端

FastAPI + SQLite + Alembic 实现的旅行沟通助手后端服务。

## 启动

```bash
cp .env.example .env
uv sync --extra dev
uv run alembic upgrade head
uv run uvicorn app.main:app --reload --port 8000
```

## 测试

```bash
uv run pytest
```

详见仓库根目录 [README.md](../README.md) 与 [docs/](../docs/)。
