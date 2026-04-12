# API 参考

基址：`http://<host>:8000/api/v1`

所有请求/响应均为 JSON。错误使用 HTTP 状态码 + `{error, detail}` 响应体。

## 1. 翻译

### POST /translate

请求：

```json
{
  "source_text": "请给我看菜单",
  "source_language": "zh",
  "target_language": "ja",
  "context": "restaurant"
}
```

响应：

```json
{
  "translated_text": "メニューを見せてください",
  "transliteration": "menyuu wo misete kudasai",
  "confidence": 0.95,
  "engine": "anthropic",
  "cached": false
}
```

## 2. 场景短语

### GET /phrases/packages/{language}?category=restaurant

返回指定语言的预置 + 用户自定义短语包。`category` 可选。

```json
{
  "language": "ja",
  "total": 30,
  "phrases": [
    {
      "id": "…",
      "scene_category": "restaurant",
      "subcategory": "点餐",
      "source_text": "请给我看菜单",
      "target_text": "メニューを見せてください",
      "transliteration": "menyuu wo misete kudasai",
      "is_custom": false,
      "priority": 10
    }
  ]
}
```

### POST /phrases/custom

创建自定义短语（返回 `201`）。

## 3. 对话

### POST /conversations

```json
{
  "destination": "东京",
  "source_language": "zh",
  "target_language": "ja"
}
```

### POST /conversations/{id}/messages

```json
{
  "speaker": "user",
  "source_text": "请问去东京塔怎么走？",
  "input_type": "text"
}
```

后端自动根据 `speaker` 选择翻译方向（user → 目标语言；counterpart → 源语言）。

### GET /conversations/{id}

返回对话详情，含 `messages` 数组。

## 4. 收藏

- `POST /favorites` — 创建
- `GET /favorites?user_id=…` — 列出
- `DELETE /favorites/{id}` — 删除

## 5. OCR & Speech（后备通道，默认返回 stub）

- `POST /ocr/translate` — multipart 上传图片，后备实现
- `POST /speech/recognize` — multipart 上传音频，后备实现

真实识别建议在端侧完成：
- Android：Google ML Kit / Android SpeechRecognizer
- iOS：Vision Framework / Speech Framework

## 错误格式

```json
{ "error": "InternalServerError", "detail": "..." }
```

FastAPI 内置的 404 / 422 错误沿用默认结构。
