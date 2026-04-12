# TravelTranslator — 旅行沟通助手

> 学英语的产品核心是"理解深度"，旅行翻译的核心是**沟通效率**。
> 本仓库是 PROJECT.md 设计的 MVP 实现：Python 后端 + Android 客户端 + iOS 客户端。

完整产品设计见 [PROJECT.md](PROJECT.md)，项目工作流程约定见 [AGENTS.md](AGENTS.md)。

## 目录结构

```
travelTranslate/
├── backend/          # FastAPI + SQLite + Alembic 后端
├── android/          # Kotlin + Jetpack Compose + Hilt + Room 客户端
├── ios/              # Swift + SwiftUI 客户端
├── docs/             # 架构/数据模型/API 文档
├── PROJECT.md        # 产品设计文档
└── AGENTS.md         # 项目协作规范
```

## 快速开始

### 后端

```bash
cd backend
cp .env.example .env
uv sync --extra dev
uv run alembic upgrade head           # 应用数据库迁移
uv run uvicorn app.main:app --reload --port 8000
```

- 首次启动会自动导入 `app/data/phrases/*.json` 中的预置短语。
- 接口文档：http://localhost:8000/docs
- 健康检查：http://localhost:8000/health

测试：

```bash
cd backend
uv run pytest
```

### Android

1. 用 Android Studio (Giraffe+) 打开 `android/` 目录
2. 在 `local.properties` 或 Gradle 命令中设置 `API_BASE_URL`：
   - 模拟器默认：`http://10.0.2.2:8000/`
   - 真机：`http://<你的局域网 IP>:8000/`
3. Build → Run

### iOS

1. 用 Xcode 15+ 打开 `ios/Package.swift`，或新建一个 iOS App 项目并引入 `ios/TravelTranslator/` 目录
2. 将 `TravelTranslator/Resources/Info.plist.template` 的内容合并进真正的 Info.plist
3. 修改 `API_BASE_URL` 指向后端地址
4. Build & Run，最低支持 iOS 17

## 核心能力

| 能力 | 后端 | Android | iOS |
|------|------|---------|-----|
| 文本翻译（缓存 + Claude 引擎） | ✅ | ✅ | ✅ |
| 场景短语包（日/韩/英） | ✅ | ✅ | ✅ |
| 双向对话模式 | ✅ | ✅ | ✅ |
| 收藏 | ✅ | ✅ (本地) | ✅ (本地) |
| 全屏展示模式 | — | ✅ | ✅ |
| TTS 朗读 | — | (系统 TTS 待接入) | ✅ (AVSpeech) |
| 拍照翻译 OCR | Stub 接口 | 待接入 ML Kit | 待接入 Vision |
| 语音识别 ASR | Stub 接口 | 待接入 | 待接入 |

## 配置与安全

- **禁止**在代码中硬编码 API Key；后端 `.env` 中通过 `ANTHROPIC_API_KEY` 注入翻译引擎密钥。
- 默认 `TRANSLATION_ENGINE=mock`，使用内置兜底字典，便于离线/无 Key 开发。
- 设置 `TRANSLATION_ENGINE=anthropic` 并填入 `ANTHROPIC_API_KEY` 后启用 Claude 翻译。

## 更多文档

- [docs/architecture.md](docs/architecture.md) — 整体架构
- [docs/api.md](docs/api.md) — API 参考
- [docs/schema.md](docs/schema.md) — 数据模型
