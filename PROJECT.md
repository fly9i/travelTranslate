# TravelTranslator — 旅行沟通助手 产品设计文档

> **产品定位**：不是"翻译器"，是"旅行沟通助手"。  
> **核心理念**：学英语的产品核心是"理解深度"，旅行翻译的核心是**沟通效率**。  
> **目标平台**：Android / iOS / 后端服务

---

## 一、产品背景与目标

### 1.1 目标用户

出境旅行的中文用户，不具备目的地语言的日常会话能力，需要在餐厅、交通、酒店、购物、紧急求助等场景中快速完成沟通。

### 1.2 核心场景特征

| 维度 | 通用翻译 / 学英语 | 旅行场景（本产品） |
|------|-------------------|-------------------|
| 核心诉求 | 理解深度、词汇积累 | **快、准、能沟通** |
| 使用时长 | 坐下来慢慢学 | **几秒内完成** |
| 网络条件 | Wi-Fi 为主 | **经常无网 / 弱网** |
| 输入方式 | 打字为主 | **语音 / 拍照 / 打字** |
| 输出形式 | 文字阅读 | **给对方看 / 给对方听** |
| 难词提取 | 核心功能 | 不需要 |
| 情感分析 | 有价值 | 不需要 |

### 1.3 设计原则

1. **3 秒原则** — 从打开 App 到发出翻译结果不超过 3 秒
2. **展示优先** — 翻译结果默认为"给对方看"的大字展示模式
3. **离线可用** — 核心场景短语 100% 离线可用，翻译引擎支持离线降级
4. **目的地驱动** — 用户选择目的地后，语言、场景、短语自动匹配

---

## 二、功能架构

```
TravelTranslator
├── 首页（目的地 + 场景入口 + 即时翻译）
├── 场景短语本（分类预置短语 + 自定义）
├── 实时对话模式（双向语音翻译）
├── 拍照翻译（OCR + 翻译）
├── 收藏夹（收藏短语管理）
└── 设置（目的地管理 / 离线包 / TTS 语音选择）
```

---

## 三、核心页面设计

### 3.1 首页 — 目的地 + 场景快捷入口 + 即时翻译

```
┌─────────────────────────────────┐
│  🇯🇵 东京              [切换目的地] │
├─────────────────────────────────┤
│                                 │
│  ┌──────┐  ┌──────┐  ┌──────┐  │
│  │ 🍜   │  │ 🚃   │  │ 🏨   │  │
│  │ 餐厅 │  │ 交通 │  │ 酒店 │  │
│  └──────┘  └──────┘  └──────┘  │
│  ┌──────┐  ┌──────┐  ┌──────┐  │
│  │ 🛍️   │  │ 🚨   │  │ 🗺️   │  │
│  │ 购物 │  │ 急救 │  │ 问路 │  │
│  └──────┘  └──────┘  └──────┘  │
│                                 │
│  ┌─────────────────────────────┐│
│  │  说点什么 / 拍照翻译...     ││
│  │              🎤   📷   ⌨️   ││
│  └─────────────────────────────┘│
│                                 │
│  [最近使用]                      │
│   "请问洗手间在哪里？"       →   │
│   "请给我菜单"               →   │
└─────────────────────────────────┘
  ┌──────┬──────┬──────┬──────┐
  │ 翻译 │ 场景 │ 收藏 │ 设置 │
  └──────┴──────┴──────┴──────┘
```

**设计要点：**

- 顶部显示当前目的地及国旗，一键切换
- 场景网格区：6 个核心场景快捷入口（餐厅、交通、酒店、购物、急救、问路），可根据目的地动态调整
- 输入区：语音、拍照、文字三种输入方式并列，语音为主推交互
- 最近使用：快速重发历史翻译，旅行中复用率极高
- 底部导航：翻译（首页）/ 场景 / 收藏 / 设置

### 3.2 场景短语本 — 替代"难词本"

点击场景（如"餐厅"）进入该场景的常用短语页：

```
┌─────────────────────────────────┐
│  ←  🍜 餐厅常用                  │
├─────────────────────────────────┤
│                                 │
│  ── 点餐 ──                     │
│  ┌─────────────────────────────┐│
│  │  请给我看菜单                ││
│  │  メニューを見せてください      ││
│  │                 [🔊] [📺展示] ││
│  └─────────────────────────────┘│
│  ┌─────────────────────────────┐│
│  │  我对花生过敏                ││
│  │  ピーナッツアレルギーです      ││
│  │                 [🔊] [📺展示] ││
│  └─────────────────────────────┘│
│  ┌─────────────────────────────┐│
│  │  推荐一下你们的招牌菜        ││
│  │  おすすめ料理は何ですか？     ││
│  │                 [🔊] [📺展示] ││
│  └─────────────────────────────┘│
│                                 │
│  ── 结账 ──                     │
│  ┌─────────────────────────────┐│
│  │  可以刷卡吗？                ││
│  │  カードは使えますか？         ││
│  │                 [🔊] [📺展示] ││
│  └─────────────────────────────┘│
│                                 │
│  [＋ 添加自定义短语]              │
└─────────────────────────────────┘
```

**核心交互：**

- **[📺展示] 按钮**：全屏大字显示译文，直接递给对方看 — 这是旅行翻译**最高频**的操作
- **[🔊] 按钮**：TTS 朗读译文，让对方听
- **预置 + 自定义**：每个场景预装 15-30 条常用短语，用户可随时添加
- **离线可用**：所有预置短语随离线包下载，无网络也能使用

**展示模式（全屏）：**

```
┌─────────────────────────────────┐
│                                 │
│                                 │
│    メニューを見せてください       │
│    (请给我看菜单)                │
│                                 │
│                                 │
│           [ 🔊 朗读 ]            │
│           [ ✕ 关闭 ]            │
└─────────────────────────────────┘
```

- 目标语言大字居中，底部附小字原文
- 背景高对比，户外强光下可读
- 支持亮度自动调至最高

### 3.3 实时对话模式 — 双向语音翻译

```
┌─────────────────────────────────┐
│  ←  实时对话          🇨🇳 ↔ 🇯🇵   │
├─────────────────────────────────┤
│                                 │
│  🧑 你                          │
│  ┌─────────────────────────────┐│
│  │  请问去东京塔怎么走？        ││
│  │  東京タワーへの行き方を       ││
│  │  教えてください               ││
│  └─────────────────────────────┘│
│                                 │
│  👤 对方                         │
│  ┌─────────────────────────────┐│
│  │  駅まで歩いて5分くらいです    ││
│  │  走到车站大约5分钟            ││
│  └─────────────────────────────┘│
│                                 │
│  🧑 你                          │
│  ┌─────────────────────────────┐│
│  │  谢谢！大概多少钱？          ││
│  │  ありがとう！いくらですか？    ││
│  └─────────────────────────────┘│
│                                 │
├─────────────────────────────────┤
│  🎤 按住说话（中文）              │
│  ──────────────────────────────  │
│  [🔄 切换到对方说话]              │
└─────────────────────────────────┘
```

**设计要点：**

- 聊天气泡式布局，清晰区分双方发言
- 每条消息同时显示原文 + 译文
- 底部"按住说话"按钮，一键切换"我说中文"/"对方说日文"
- 支持自动语音识别（ASR）+ 翻译 + TTS 朗读的连续流程
- 对话记录可保存、可导出

### 3.4 拍照翻译

```
┌─────────────────────────────────┐
│  ←  拍照翻译          🇨🇳 → 🇯🇵   │
├─────────────────────────────────┤
│                                 │
│  ┌─────────────────────────────┐│
│  │                             ││
│  │      [ 相机取景画面 ]        ││
│  │                             ││
│  │   检测到的文字区域高亮覆盖    ││
│  │                             ││
│  └─────────────────────────────┘│
│                                 │
│  ── 识别结果 ──                  │
│  原文：本日のおすすめ            │
│  译文：今日推荐                  │
│                                 │
│         [📺展示]  [⭐收藏]       │
│                                 │
├─────────────────────────────────┤
│        [📷 拍照]  [🖼 相册]      │
└─────────────────────────────────┘
```

**典型使用场景：**

- 餐厅菜单（最高频）
- 路牌、地铁线路图
- 药品说明书
- 票据、收据
- 景点介绍牌

**技术方案：** 端侧 OCR（Google ML Kit / Apple Vision）+ 后端翻译 API

---

## 四、场景分类与预置短语设计

### 4.1 场景分类体系

| 场景 | 子分类 | 预置短语数 |
|------|--------|-----------|
| 🍜 餐厅 | 点餐、过敏/忌口、结账、投诉 | 25-30 |
| 🚃 交通 | 问路、买票、打车、公交/地铁 | 20-25 |
| 🏨 酒店 | 入住、退房、客房服务、投诉 | 20-25 |
| 🛍️ 购物 | 询价、砍价、退换、免税 | 15-20 |
| 🚨 急救 | 身体不适、报警、求助、药品 | 15-20 |
| 🗺️ 问路 | 方向、距离、地标、推荐 | 15-20 |
| 💬 日常 | 问候、感谢、道歉、数字 | 10-15 |

### 4.2 短语示例（餐厅 - 日语）

**点餐：**
- 请给我看菜单 → メニューを見せてください
- 有英文菜单吗？ → 英語のメニューはありますか？
- 推荐一下招牌菜 → おすすめ料理は何ですか？
- 我要这个 → これをお願いします
- 不要太辣 → あまり辛くしないでください

**过敏/忌口：**
- 我对花生过敏 → ピーナッツアレルギーです
- 我不吃猪肉 → 豚肉は食べられません
- 有素食选项吗？ → ベジタリアンメニューはありますか？

**结账：**
- 买单 → お会計をお願いします
- 可以刷卡吗？ → カードは使えますか？
- 可以用微信/支付宝吗？ → WeChat Pay/Alipayは使えますか？
- 请开发票 → 領収書をお願いします

### 4.3 多目的地语言适配

预置短语按目的地维护独立语言包：

| 目的地 | 语言 | 短语包文件 |
|--------|------|-----------|
| 🇯🇵 日本 | 日语 | `phrases_ja.json` |
| 🇰🇷 韩国 | 韩语 | `phrases_ko.json` |
| 🇹🇭 泰国 | 泰语 | `phrases_th.json` |
| 🇫🇷 法国 | 法语 | `phrases_fr.json` |
| 🇪🇸 西班牙 | 西班牙语 | `phrases_es.json` |
| 🇮🇹 意大利 | 意大利语 | `phrases_it.json` |
| 🇩🇪 德国 | 德语 | `phrases_de.json` |
| 🇺🇸 英语区 | 英语 | `phrases_en.json` |

每个语言包格式：

```json
{
  "language": "ja",
  "destination": "日本",
  "version": "1.0.0",
  "scenes": [
    {
      "category": "restaurant",
      "name": "餐厅",
      "icon": "🍜",
      "subcategories": [
        {
          "name": "点餐",
          "phrases": [
            {
              "id": "rest_order_001",
              "source": "请给我看菜单",
              "target": "メニューを見せてください",
              "pinyin": "menyuu wo misete kudasai",
              "priority": 1
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 五、技术架构

### 5.1 整体架构

```
┌─────────────────────────────────────────────────┐
│                    客户端                         │
│  ┌──────────────┐      ┌──────────────────────┐  │
│  │  Android App │      │      iOS App         │  │
│  │  (Kotlin)    │      │  (Swift / SwiftUI)   │  │
│  └──────┬───────┘      └──────────┬───────────┘  │
│         │                        │               │
│         └────────┬───────────────┘               │
│                  │                               │
│           端侧能力层                              │
│    ┌─────────────┼──────────────┐                │
│    │  ASR  │  OCR  │  TTS  │  离线翻译  │        │
│    └─────────────┼──────────────┘                │
└──────────────────┼──────────────────────────────┘
                   │ HTTPS / WebSocket
┌──────────────────┼──────────────────────────────┐
│                后端服务                           │
│  ┌───────────────┼────────────────────────────┐  │
│  │          API Gateway (Nginx)               │  │
│  └───────────────┼────────────────────────────┘  │
│                  │                               │
│  ┌───────────────┼────────────────────────────┐  │
│  │       应用服务 (Python / FastAPI)           │  │
│  │  ┌──────────────────────────────────────┐  │  │
│  │  │  翻译服务  │  对话管理  │  用户管理    │  │  │
│  │  │  OCR服务   │  短语同步  │  数据统计    │  │  │
│  │  └──────────────────────────────────────┘  │  │
│  └───────────────┼────────────────────────────┘  │
│                  │                               │
│  ┌───────────────┼────────────────────────────┐  │
│  │  PostgreSQL  │  Redis  │  对象存储 (S3)    │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### 5.2 客户端技术栈

| 层级 | Android | iOS |
|------|---------|-----|
| 语言 | Kotlin | Swift |
| UI 框架 | Jetpack Compose | SwiftUI |
| 网络 | Retrofit + OkHttp | URLSession / Alamofire |
| 本地存储 | Room | Core Data / SwiftData |
| 语音识别 (ASR) | Google ML Kit / SpeechRecognizer | Apple Speech Framework |
| 文字识别 (OCR) | Google ML Kit Text Recognition | Apple Vision Framework |
| 语音合成 (TTS) | Android TTS / Google Cloud TTS | AVSpeechSynthesizer |
| 离线翻译 | Google ML Kit Translation | Apple Translation API |
| 依赖注入 | Hilt | Swift 原生 |
| 图片加载 | Coil | SDWebImage / Kingfisher |

### 5.3 后端技术栈

| 组件 | 技术选型 | 说明 |
|------|---------|------|
| Web 框架 | **FastAPI** (Python) | 异步高性能，开发效率高 |
| 数据库 | **PostgreSQL** | 关系数据 + 后续可扩展 pgvector |
| 缓存 | **Redis** | 翻译缓存、会话管理、频率限制 |
| 对象存储 | S3 / MinIO | 离线语言包、语音文件 |
| 翻译引擎 | Claude API / DeepL / Google Translate | 多引擎备份，按质量和成本路由 |
| OCR 引擎 | Google Cloud Vision (后端备用) | 端侧 OCR 失败时的后备方案 |
| 部署 | Docker + Docker Compose | 开发/生产一致 |
| CI/CD | GitHub Actions | 自动化构建和部署 |

### 5.4 API 设计

#### 翻译接口

```
POST /api/v1/translate
{
  "source_text": "请给我看菜单",
  "source_language": "zh",
  "target_language": "ja",
  "context": "restaurant",        // 场景上下文，提升翻译准确度
  "conversation_id": "uuid"       // 可选，对话模式下带上下文
}

Response:
{
  "translated_text": "メニューを見せてください",
  "transliteration": "menyuu wo misete kudasai",   // 注音/罗马音
  "confidence": 0.95,
  "engine": "claude"
}
```

#### 语音识别接口

```
POST /api/v1/speech-to-text
Content-Type: multipart/form-data

file: <audio_file>
language: "zh"

Response:
{
  "text": "请问洗手间在哪里",
  "confidence": 0.92
}
```

#### 对话管理接口

```
POST /api/v1/conversations
{
  "destination": "东京",
  "language_pair": "zh-ja"
}

POST /api/v1/conversations/{id}/messages
{
  "speaker": "user",              // user | counterpart
  "source_text": "请问去东京塔怎么走？",
  "input_type": "voice"           // voice | text | photo
}
```

#### 短语同步接口

```
GET  /api/v1/phrases/packages/{language}?version={local_version}
POST /api/v1/phrases/custom         // 上传用户自定义短语
GET  /api/v1/phrases/custom         // 拉取用户自定义短语
```

#### OCR 翻译接口

```
POST /api/v1/ocr/translate
Content-Type: multipart/form-data

image: <image_file>
target_language: "zh"

Response:
{
  "blocks": [
    {
      "original_text": "本日のおすすめ",
      "translated_text": "今日推荐",
      "bounding_box": { "x": 10, "y": 20, "width": 200, "height": 30 }
    }
  ]
}
```

---

## 六、数据模型设计

### 6.1 数据库 ER 关系

```
users ──< conversations ──< messages
  │
  └──< favorite_phrases

scene_phrases (预置，独立维护)

phrase_packages (离线包版本管理)
```

### 6.2 表结构

```sql
-- 用户表
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id       VARCHAR(255) NOT NULL,
    default_source_language VARCHAR(10) DEFAULT 'zh',
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- 场景短语表（预置 + 用户自定义）
CREATE TABLE scene_phrases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scene_category  VARCHAR(50) NOT NULL,         -- restaurant / transport / hotel ...
    subcategory     VARCHAR(50),                   -- ordering / checkout / complaint ...
    source_text     TEXT NOT NULL,
    target_text     TEXT NOT NULL,
    target_language VARCHAR(10) NOT NULL,           -- ja / ko / th / fr ...
    transliteration TEXT,                           -- 注音/罗马音
    is_custom       BOOLEAN DEFAULT FALSE,          -- 是否用户自定义
    user_id         UUID REFERENCES users(id),      -- 自定义短语关联用户
    use_count       INTEGER DEFAULT 0,
    priority        INTEGER DEFAULT 0,              -- 排序权重
    last_used_at    TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_scene_phrases_category ON scene_phrases(scene_category, target_language);
CREATE INDEX idx_scene_phrases_user ON scene_phrases(user_id) WHERE is_custom = TRUE;

-- 对话记录表
CREATE TABLE conversations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id),
    destination     VARCHAR(100),                   -- 目的地名称
    source_language VARCHAR(10) NOT NULL,
    target_language VARCHAR(10) NOT NULL,
    message_count   INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- 对话消息表
CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    speaker         VARCHAR(20) NOT NULL,           -- 'user' | 'counterpart'
    source_text     TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    input_type      VARCHAR(20) DEFAULT 'text',     -- text | voice | photo
    audio_url       TEXT,                           -- 语音文件 URL
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at);

-- 收藏短语表
CREATE TABLE favorite_phrases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id),
    source_text     TEXT NOT NULL,
    target_text     TEXT NOT NULL,
    target_language VARCHAR(10) NOT NULL,
    scene_category  VARCHAR(50),
    source_phrase_id UUID,                          -- 关联原始短语（可选）
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_favorites_user ON favorite_phrases(user_id);

-- 翻译缓存表（高频翻译缓存）
CREATE TABLE translation_cache (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_text     TEXT NOT NULL,
    source_language VARCHAR(10) NOT NULL,
    target_language VARCHAR(10) NOT NULL,
    translated_text TEXT NOT NULL,
    engine          VARCHAR(50),
    hit_count       INTEGER DEFAULT 1,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(source_text, source_language, target_language)
);
```

### 6.3 客户端本地数据库（Room / Core Data）

```
-- 本地场景短语（从离线包加载 + 用户自定义）
local_scene_phrases(id, scene_category, subcategory, source_text, 
                    target_text, target_language, transliteration,
                    is_custom, use_count, last_used_at)

-- 本地对话记录
local_conversations(id, destination, source_language, target_language,
                    message_count, synced, created_at)

-- 本地对话消息
local_messages(id, conversation_id, speaker, source_text, 
               translated_text, input_type, audio_path, created_at)

-- 本地收藏
local_favorites(id, source_text, target_text, target_language,
                scene_category, synced, created_at)

-- 离线包版本
package_versions(language, version, downloaded_at)
```

---

## 七、离线策略

### 7.1 离线能力分级

| 功能 | 离线支持 | 实现方式 |
|------|---------|---------|
| 场景短语浏览 | ✅ 完全支持 | 本地数据库 |
| 短语 TTS 朗读 | ✅ 完全支持 | 系统 TTS / 预录音频 |
| 短语展示模式 | ✅ 完全支持 | 纯本地渲染 |
| 实时文字翻译 | ⚠️ 降级支持 | ML Kit 离线翻译（质量略低） |
| 语音识别 | ⚠️ 降级支持 | 系统 ASR 离线模式 |
| 拍照翻译 | ⚠️ 降级支持 | 端侧 OCR + 离线翻译 |
| 对话模式 | ⚠️ 降级支持 | 端侧 ASR + 离线翻译 |
| 翻译质量最优 | ❌ 需联网 | Claude API / DeepL |

### 7.2 离线语言包

- 首次选择目的地时提示下载离线包
- 离线包内容：预置短语数据 + ML Kit 离线翻译模型 + TTS 语音模型
- 单语言包大小目标：< 50MB
- 增量更新：仅下载版本差异

---

## 八、项目结构

### 8.1 后端项目结构

```
backend/
├── app/
│   ├── main.py                    # FastAPI 入口
│   ├── config.py                  # 配置管理
│   ├── models/                    # SQLAlchemy 模型
│   │   ├── user.py
│   │   ├── conversation.py
│   │   ├── message.py
│   │   ├── phrase.py
│   │   └── translation_cache.py
│   ├── schemas/                   # Pydantic 请求/响应模型
│   │   ├── translate.py
│   │   ├── conversation.py
│   │   └── phrase.py
│   ├── api/                       # 路由
│   │   ├── v1/
│   │   │   ├── translate.py
│   │   │   ├── conversations.py
│   │   │   ├── phrases.py
│   │   │   ├── ocr.py
│   │   │   └── speech.py
│   │   └── router.py
│   ├── services/                  # 业务逻辑
│   │   ├── translation_service.py # 翻译引擎路由
│   │   ├── ocr_service.py
│   │   ├── speech_service.py
│   │   └── cache_service.py
│   ├── core/                      # 基础设施
│   │   ├── database.py
│   │   ├── redis.py
│   │   └── storage.py
│   └── utils/
├── migrations/                    # Alembic 数据库迁移
├── data/
│   └── phrases/                   # 预置短语 JSON 文件
│       ├── phrases_ja.json
│       ├── phrases_ko.json
│       └── ...
├── tests/
├── Dockerfile
├── docker-compose.yml
└── requirements.txt
```

### 8.2 Android 项目结构

```
android/
├── app/src/main/
│   ├── java/com/traveltranslator/
│   │   ├── di/                        # Hilt 依赖注入
│   │   ├── data/
│   │   │   ├── local/                 # Room 数据库
│   │   │   │   ├── AppDatabase.kt
│   │   │   │   ├── dao/
│   │   │   │   └── entity/
│   │   │   ├── remote/                # API 服务
│   │   │   │   ├── ApiService.kt
│   │   │   │   └── dto/
│   │   │   └── repository/
│   │   ├── domain/
│   │   │   ├── model/
│   │   │   └── usecase/
│   │   ├── ui/
│   │   │   ├── home/                  # 首页
│   │   │   ├── scene/                 # 场景短语
│   │   │   ├── conversation/          # 对话模式
│   │   │   ├── camera/                # 拍照翻译
│   │   │   ├── favorites/             # 收藏
│   │   │   ├── settings/              # 设置
│   │   │   ├── display/               # 全屏展示
│   │   │   ├── components/            # 共享组件
│   │   │   └── theme/
│   │   └── service/
│   │       ├── TranslationService.kt  # 翻译（在线/离线）
│   │       ├── SpeechService.kt       # ASR + TTS
│   │       └── OcrService.kt          # 文字识别
│   └── res/
├── build.gradle.kts
└── ...
```

### 8.3 iOS 项目结构

```
ios/TravelTranslator/
├── App/
│   ├── TravelTranslatorApp.swift
│   └── ContentView.swift
├── Models/
│   ├── Phrase.swift
│   ├── Conversation.swift
│   └── Message.swift
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── SceneGridView.swift
│   ├── Scene/
│   │   ├── SceneListView.swift
│   │   └── PhraseCardView.swift
│   ├── Conversation/
│   │   ├── ConversationView.swift
│   │   └── MessageBubbleView.swift
│   ├── Camera/
│   │   ├── CameraView.swift
│   │   └── OcrResultView.swift
│   ├── Display/
│   │   └── FullScreenDisplayView.swift
│   ├── Favorites/
│   │   └── FavoritesView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── TranslationService.swift
│   ├── SpeechService.swift
│   ├── OcrService.swift
│   └── NetworkService.swift
├── Persistence/
│   ├── CoreDataStack.swift
│   └── TravelTranslator.xcdatamodeld
├── Resources/
│   └── Phrases/
└── ...
```

---

## 九、实施路线图

### Phase 1 — MVP（第 1-4 周）

**目标：跑通核心翻译链路**

- [ ] 后端：FastAPI 项目搭建 + PostgreSQL + 翻译 API（Claude/DeepL）
- [ ] 后端：`/translate`、`/phrases` 接口
- [ ] Android：项目搭建（Compose + Room + Hilt）
- [ ] Android：首页 UI（目的地选择 + 输入框 + 场景网格）
- [ ] Android：基础翻译功能（文字输入 → 翻译 → 展示）
- [ ] 数据：日语短语包（餐厅 + 交通 场景）

### Phase 2 — 核心体验（第 5-8 周）

**目标：旅行场景可用**

- [ ] 场景短语本完整实现（浏览 / 展示模式 / TTS 朗读）
- [ ] 全屏展示模式
- [ ] 语音输入（ASR）集成
- [ ] 实时对话模式 MVP
- [ ] 收藏功能
- [ ] 离线短语支持
- [ ] 更多语言包（韩语、泰语、英语）

### Phase 3 — 体验提升（第 9-12 周）

**目标：产品打磨 + iOS 启动**

- [ ] 拍照翻译（OCR）
- [ ] 离线翻译引擎集成（ML Kit）
- [ ] 对话历史记录与导出
- [ ] iOS 项目搭建 + 核心功能移植
- [ ] 翻译缓存优化（Redis）
- [ ] UI 打磨（动画、过渡、暗色模式）

### Phase 4 — 完善发布（第 13-16 周）

**目标：双端发布**

- [ ] iOS 功能对齐
- [ ] 数据同步（跨设备收藏/自定义短语同步）
- [ ] 性能优化（启动速度、翻译延迟）
- [ ] 多语言 UI（App 自身的多语言支持）
- [ ] 应用市场素材准备
- [ ] Android Google Play + iOS App Store 上线

---

## 十、关键指标

| 指标 | 目标值 |
|------|--------|
| 翻译响应时间（联网） | < 1.5s |
| 翻译响应时间（离线） | < 0.5s |
| App 启动到可用 | < 2s |
| 展示模式打开 | < 0.3s |
| 语音识别准确率 | > 90% |
| OCR 识别准确率 | > 85% |
| 离线包单语言大小 | < 50MB |
| App 安装包大小 | < 30MB（不含离线包） |
| 崩溃率 | < 0.1% |

---

## 附录

### A. 竞品参考

- Google Translate — 全能但旅行场景不聚焦
- Papago（Naver）— 亚洲语言优势，但缺乏场景化设计
- iTranslate — 对话模式体验好
- Waygo — 拍照翻译菜单，垂直场景做得深

### B. 风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| 翻译 API 成本 | 高频使用下费用增长 | 翻译缓存 + 端侧离线引擎分流 |
| 离线翻译质量 | 用户体验下降 | 预置高频短语兜底 + 提示联网 |
| 语音识别口音问题 | 识别准确率低 | 多引擎备选 + 允许手动纠正 |
| 多语言维护成本 | 短语包需人工审核 | 先覆盖 Top 5 目的地，逐步扩展 |