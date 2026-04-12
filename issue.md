# 产品改进计划

4 项待办，优先级由上至下。

---

## 1️⃣ 拍照抠图识别 — 完全没做

### 现状
- 后端 `backend/app/api/v1/ocr.py:48` 是 stub，返回空 blocks
- iOS 端无任何 Camera/OCR 相关的 View

### 方案：端侧 iOS Vision framework
无网络依赖、免费、支持中日韩英等主流语种。

**流程：**
1. 相机拍照 / 从相册选照片
2. `VNRecognizeTextRequest` 识别文字块 + bounding box
3. 批量调用现有 `/api/v1/translate` 接口翻译
4. 把译文"贴"回原图位置（AR 覆盖的观感）

**新增文件：**
- `Views/Camera/CameraOCRView.swift`
- `Services/OCRService.swift`

**工程量：** ~300 行

**取舍：**
- 不走云 OCR（Google Vision）→ 无需管 API Key 和费用
- 代价：小众语言（泰文 / 阿拉伯文）识别精度一般，可后续再做后端兜底

---

## 2️⃣ 实时对话翻译支持语音 — 完全没做

### 现状
- `ios/TravelTranslator/Services/SpeechService.swift` 只有 TTS（朗读），没有 STT（语音转文字）
- `ios/TravelTranslator/Views/Conversation/ConversationView.swift:34` 只有 TextField 文字输入

### 方案：iOS `Speech` framework（`SFSpeechRecognizer`）
iOS 17 上大多数语种支持 **on-device** 识别，隐私好、延迟低。

**UI 改动：**
- 在"发送"按钮旁加麦克风按钮
- **按住说话 / 松开识别**
- 识别完的文字直接写入 `viewModel.input`，自动触发翻译
- 译文用 TTS 朗读出来
- 保留说话人切换按钮

**新增文件：**
- `Services/SpeechRecognitionService.swift`
- 修改 `Views/Conversation/ConversationView.swift`

**工程量：** ~200 行

**权限：** `NSSpeechRecognitionUsageDescription` 和 `NSMicrophoneUsageDescription` 已在 `ios/project.yml` 里配好

**取舍：**
- iOS Speech 单 session 有 1 分钟硬限制 → 按住说话模式够用
- "持续流式对话"需要手动分段，工程复杂度翻倍 → 暂不做

---

## 3️⃣ 目的地切换 — GPS 默认 + 选择器

### 现状
- `ios/TravelTranslator/App/AppState.swift:8` 的 `switchDestination()` 是点一下按列表轮询下一个
- 只有 6 个硬编码目的地，且无法搜索
- 无任何 GPS 定位

### 方案：拆两步

**Step 1：GPS 默认位置**
- 首次启动请求 `CoreLocation`（`WhenInUse`）
- 反向地理编码拿当前国家码，查 `Destinations.all` 匹配默认目的地
- 没匹配上则 fall back 到当前值
- `project.yml` 加 `NSLocationWhenInUseUsageDescription`

**Step 2：切换 UI**
- 点击 Home 页标题上的目的地区域 → 弹出 sheet
- Sheet 内容：带搜索框的 List，国旗 + 中文名 + 本地名
- 支持按国家 / 语言搜索
- 顺便把 `Destinations.all` 从 6 个扩充到 20+ 热门目的地

**新增文件：**
- `Services/LocationService.swift`
- `Views/Destination/DestinationPickerView.swift`
- 扩充 `Models/Destination.swift`

**工程量：** ~250 行

---

## 4️⃣ 朗读功能不好使 — 🐛 Bug 修复

### 现状
`SpeechService.swift` 逻辑本身没问题，但**少了最要命的一步：没有配置 `AVAudioSession`**。

### 根因
默认 AVSpeechSynthesizer 走 `.ambient` 通道，导致：
- ❌ **iPhone 静音开关拨到静音时，完全没声音**（最常见原因）
- ❌ 和别的 app 的音频混音，音量被压得很小
- ❌ 蓝牙耳机连接时输出路径可能错

### 修法
在 `SpeechService.init` 里：
```swift
AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
try? AVAudioSession.sharedInstance().setActive(true)
```
这样即使静音模式下也能正常出声。

### 附带保险
日语/韩语的 voice 如果用户系统里没有预装的 Enhanced 版本，
`AVSpeechSynthesisVoice(language: "ja-JP")` 有时会返回 nil 导致静默失败。
→ 加一个 fallback（尝试默认 voice）和日志。

**工程量：** ~10 行，2 分钟

---

## 🚀 建议执行顺序

| 顺序 | 任务 | 理由 |
|------|------|------|
| 1 | **#4 朗读修复** | 10 行改动，bug 不是新功能，立即能用 |
| 2 | **#3 目的地切换** | 基建型改动，#1 和 #2 都依赖 destination 的语言字段，先打磨好 |
| 3 | **#2 对话语音** | 权限已配，SpeechService 已有 TTS 半套，增量可观 |
| 4 | **#1 拍照 OCR** | 最独立、最重的新功能，单独一个大 PR |
