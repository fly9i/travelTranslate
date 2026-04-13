# 本轮迭代功能总览(供 Android 同步实现参考)

本文件汇总本次会话中讨论并在 iOS / 后端实现的全部功能,逐项给出实现要点和
Android 对应方案/组件建议,便于在 Android 端对齐。

---

## 1. OCR 覆盖率修复(小字/菜单漏识别)

### 问题
菜单图里的小字描述行、附加品名常被 Vision OCR 默认设置滤掉,导致 LLM 拿到
的 OCR 列表不全。

### iOS 实现
`ios/TravelTranslator/Services/OCRService.swift`:
- `request.recognitionLevel = .accurate`
- `request.usesLanguageCorrection = true`
- **`request.minimumTextHeight = 0`** — 放开小字高度下限(默认会丢)
- **`VNRecognizeTextRequestRevision3`**(iOS 16+,精度更高)
- `recognitionLanguages = ["en-US", "zh-Hans"]`(调用方可覆盖)

> 曾尝试 2×2 切片 + IoU 去重的"分块 OCR",结果 Vision 在裁片上会把邻近行合并
> 成巨块,跨行跨列的 box 反而更糟,**已回退**。

### Android 对应
使用 **ML Kit Text Recognition v2**(`com.google.mlkit:text-recognition` 及
中/日/韩各语种包)。ML Kit 没有 `minimumTextHeight` 这样的旋钮,小字靠的是:
1. **保证输入图分辨率**:不要提前缩小图。
2. 需要时对图像做 **预放大**(例如小于 2000px 长边的放大到 2000–3000px 后再识别)。
3. 对中/英菜单,并发调用两次识别器(`TextRecognizerOptions` + 中文 `ChineseTextRecognizerOptions`),再按 bbox IoU 合并去重。

---

## 2. 后端:视觉 prompt 强制穷举 + max_tokens 提升

### 问题
日志显示 OCR 出了 142 块,LLM 却只输出 16 个 item,菜单漏了一大堆。根因是
原 prompt 写的是"挑出值得翻译的项目,忽略装饰/页脚"—— 给了模型主观筛选空间。

### 后端实现
`backend/app/services/vision_translate_service.py::_build_prompt`:
- 明确"**必须穷举**,不要做主观筛选"
- menu 场景特殊规则:"每一道菜都必须输出一项...漏菜是严重错误"
- 只允许跳过 Logo / 装饰字 / 孤立碎片 / 明显乱码
- 增加"硬性要求"段:`ocr_indices` 必须来自列表,按阅读顺序,输出前心里数一遍
- 保留严格 JSON schema 约束

`backend/app/config.py` + `backend/.env.example`:
- `MAX_TOKENS_VISION` 默认从 4096 提到 **8192**(菜单 30+ 项时 4096 容易截断)
- `MAX_TOKENS_TEXT` / `MAX_TOKENS_BATCH` 同样走 env,便于按模型调优

### Android 对应
**后端无改动**,Android 直接调用同一个流式接口
`POST /api/v1/vision-translate/stream`(SSE),解析 `delta` 和 `final` 事件即可。
事件 payload 已在 iOS 端跑通,字段完全复用。

---

## 3. 后端日志:OCR item 在 INFO 级别输出

### 目的
方便在服务端对比 "原始 OCR 列表 vs LLM 合并后的 items" 来诊断漏识别。

### 实现
`vision_translate_service.py` 请求入口处,对每条 `OCRBlockInput` 打 `logger.info("  ocr[%d]: %s", ...)`,
原先是 `debug`。LLM 解析完的 items 也在 `logger.info` 打印 `indices / src / tgt / note`。

### Android 对应
无需改动后端,保持相同调用即可同享日志收益。

---

## 4. 详情页图片固定(滚动时不被顶走)

### iOS 实现
`ios/TravelTranslator/Views/Camera/CameraOCRView.swift`:
- 用 `GeometryReader { proxy in VStack(spacing: 0) { ... } }` 包裹整页
- 顶部 `Image(uiImage: snapshot.composedImage)` 放在 `ScrollView` **外面**,
  `.frame(maxHeight: proxy.size.height * 0.4)` 锁高度
- `ScrollView` 只包含场景卡片和翻译对照列表

### Android 对应
`CoordinatorLayout` + `AppBarLayout` + `CollapsingToolbarLayout` 的"pinned image"
变体,或更简单地:
- 外层 `Column` (Compose) / `LinearLayout` (View) 垂直分上下两块
- 上块固定 `Modifier.heightIn(max = maxHeight * 0.4f)` / `android:layout_weight` 分配
- 下块用 `LazyColumn` / `RecyclerView` 承载译文列表,独立滚动

Compose 优先写法:
```kotlin
Column {
    Image(
        bitmap = composedImage,
        contentScale = ContentScale.Fit,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(max = maxHeight * 0.4f)
            .clip(RoundedCornerShape(12.dp))
            .clickable { showPreview = true }
    )
    LazyColumn { ... scene card + items ... }
}
```

---

## 5. 历史页("收藏"改名为"历史")

### 需求
- Tab 由"收藏"改名"历史"
- **所有**翻译(文本 + 拍照)自动进历史
- iOS 本地存储,不走后端
- 拍照历史保留**原图**文件
- 所有条目默认加星 = 收藏;取消星 = 删除该条

### iOS 实现
`ios/TravelTranslator/Views/History/HistoryView.swift`(从原 FavoritesView 改名):
- Model:`HistoryEntryKind` 枚举(`.text` / `.vision`)
- `HistoryTextEntry` / `HistoryVisionItem` / `HistoryVisionEntry` / `HistoryEntry`:`Codable`
- `HistoryStore` 单例,两块存储:
  - **元数据**:`UserDefaults` 键 `history.v1` 存 JSON 数组
  - **图片**:`FileManager.default.urls(for: .documentDirectory)` 下的 `history/<uuid>.jpg`(JPEG 质量 0.8)
- `HomeView` 在文本翻译和视觉翻译的 final 事件后调用 `HistoryStore.shared.addText(...)` / `.addVision(...)`
- 点击 vision 条目 → `HistoryStore.snapshot(for:)` 重建一个 `OCRSnapshot`(rawBlocks 留空,items/sceneType/summary 从磁盘恢复) → 复用 `CameraOCRView`
- 星按钮点击 → `HistoryStore.shared.remove(id:)` 同步删磁盘图

### Android 对应
**存储方案建议**:
- 小型可用 `DataStore (Proto 或 Preferences)` 存元数据 JSON
- 正经实现推荐 **Room**:两张表 `history_text` 和 `history_vision`,后者存 `imagePath` 指向 `filesDir/history/<uuid>.jpg`
- 图片写入 `context.filesDir.resolve("history").resolve("$uuid.jpg")`,`Bitmap.compress(JPEG, 80, out)`
- 单例 `HistoryRepository`(Hilt / Koin 注入或 `object`),提供 `addText / addVision / remove / list` suspend 方法
- UI:Compose `LazyColumn`,vision 条目显示缩略图,点击进详情(Activity/Destination 传 id,由 Repository 查出后重建对应数据类)

### Android Model 字段对齐 iOS
```kotlin
sealed class HistoryEntry { val id: String; val createdAt: Long; ... }
data class HistoryTextEntry(
    override val id: String,
    override val createdAt: Long,
    val sourceText: String,
    val translatedText: String,
    val sourceLang: String,
    val targetLang: String
) : HistoryEntry()
data class HistoryVisionEntry(
    override val id: String,
    override val createdAt: Long,
    val imagePath: String,        // 原图
    val composedImagePath: String, // 标注图(可选,也可运行时重绘)
    val sceneType: String?,
    val summary: String?,
    val items: List<HistoryVisionItem>
) : HistoryEntry()
data class HistoryVisionItem(
    val sourceText: String,
    val translatedText: String,
    val note: String?,
    val boundingBox: RectF     // Vision 归一化 0-1,左下原点 → Android 若用 ML Kit 是左上原点像素,需要统一
)
```

> ⚠️ **坐标系差异**:iOS Vision 的 bbox 是 **左下原点 0–1 归一化**;ML Kit
> 返回的是**左上原点像素坐标**。Android 端做 OCR 标注图时要按 ML Kit 原语
> 直接画,不要照搬 iOS 的 `pixelRect(for:imageSize:)` 转换(`y = (1 - maxY) * h`)。

---

## 6. App 图标(iOS / Android)

### 素材
根目录 `travelTranslate.jpg`,用 Pillow 生成多尺寸。

### iOS 实现(已完成)
- `ios/TravelTranslator/Resources/Assets.xcassets/AppIcon.appiconset/` 放 `icon-1024.png` + `Contents.json`(universal iOS 1024×1024)
- `ios/project.yml`:`ASSETCATALOG_COMPILER_APPICON_NAME: "AppIcon"`
- `project.pbxproj` 手动注册:新增 `Assets.xcassets` 文件引用、Build File、`PBXResourcesBuildPhase`,挂到 target

### Android 实现(已完成,注意 gsync 时别丢)
- `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` 尺寸 48/72/96/144/192
- 同目录下 `ic_launcher_round.png`(椭圆 mask)
- `AndroidManifest.xml` 的 `<application>` 加 `android:icon="@mipmap/ic_launcher"` 和 `android:roundIcon="@mipmap/ic_launcher_round"`
- 生成脚本:`uv run --with Pillow python -c "..."`(正方形居中裁剪 → 5 个尺寸 + 圆形 mask)

---

## 7. 详情页图片全屏预览 + 手势

### iOS 实现
`CameraOCRView.swift::ImagePreviewView`:
- 顶部图片 `.onTapGesture { showPreview = true }`,触发 `.fullScreenCover`
- 预览页 `ZStack`,黑底,图片中心放大/平移
- 手势:
  - `MagnificationGesture()`:捏合缩放,`lastScale * value` clamp 到 `[1, 5]`,抬手若 ≤1 弹回 1 并清零 offset
  - `DragGesture()`:仅在 `scale > 1` 时平移,抬手记录 `lastOffset`
  - `SimultaneousGesture(...)` 组合以上两者
  - `.onTapGesture(count: 2)`:双击在 1x 和 2.5x 之间 toggle
- 右上角 `xmark.circle.fill` 关闭,`.statusBarHidden()`

### Android 对应
**Compose 推荐实现**:
```kotlin
@Composable
fun ImagePreview(bitmap: ImageBitmap, onClose: () -> Unit) {
    var scale by remember { mutableStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    val transformState = rememberTransformableState { zoomChange, panChange, _ ->
        scale = (scale * zoomChange).coerceIn(1f, 5f)
        if (scale > 1f) offset += panChange
        if (scale <= 1f) offset = Offset.Zero
    }
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        Image(
            bitmap = bitmap,
            contentDescription = null,
            modifier = Modifier
                .align(Alignment.Center)
                .graphicsLayer(
                    scaleX = scale, scaleY = scale,
                    translationX = offset.x, translationY = offset.y
                )
                .transformable(state = transformState)
                .pointerInput(Unit) {
                    detectTapGestures(onDoubleTap = {
                        scale = if (scale > 1f) 1f else 2.5f
                        if (scale == 1f) offset = Offset.Zero
                    })
                }
        )
        IconButton(
            onClick = onClose,
            modifier = Modifier.align(Alignment.TopEnd).padding(16.dp)
        ) { Icon(Icons.Default.Close, null, tint = Color.White) }
    }
}
```

作为 `Dialog(DialogProperties(usePlatformDefaultWidth = false))` 或全屏
Activity 呈现。

---

## 8. 分享功能

### 需求差异(重要)
- **详情页工具栏**:分享 → **合成长图**(标注图 + 场景卡片 + 完整原文译文对照表 + 水印)
- **预览页右上角**:分享 → **仅标注图**(`snapshot.composedImage` 原样)

### iOS 实现
`CameraOCRView.swift`:

1. `ShareSheet`:`UIViewControllerRepresentable` 包 `UIActivityViewController`
2. `PosterRenderer.render(snapshot:) -> UIImage?`:
   - 用 iOS 16 `ImageRenderer(content: SharePosterView(snapshot: snapshot).frame(width: 800).background(...))`
   - `renderer.scale = 2` → 输出 1600px 宽的 PNG
3. `SharePosterView`:纯 SwiftUI 视图,布局 = 顶图 + 场景卡片 + 完整 items 列表(复用 `TranslateItemRow`)+ 右下 "TravelTranslator" 水印
4. 详情页工具栏:`ToolbarItem(.topBarTrailing)` → `square.and.arrow.up` → 调 `PosterRenderer.render` 得到长图 → `sheet(item: $shareItem)` 弹 `ShareSheet`
5. 预览页右上角:并排两个 button,分享传 `snapshot.composedImage`,关闭调 `onClose`
6. `ShareItem`:`Identifiable` 包装 `UIImage`,给 `sheet(item:)` 用

### Android 对应

**长图渲染方案**(对齐 iOS 长图效果):
- Compose 推荐 `ComposeView.drawToBitmap()` 或使用 `AndroidView` 配合 `PictureDrawable`
- 更稳妥:写一个 `@Composable fun SharePoster(snapshot)`,用 `captureToBitmap` 库(如 `dev.shreyaspatil:capturable`)或自己实现:
  ```kotlin
  suspend fun renderPoster(snapshot: OCRSnapshot): Bitmap {
      val composeView = ComposeView(context).apply {
          setContent { SharePoster(snapshot) }
          layoutParams = ViewGroup.LayoutParams(800.dpToPx(), WRAP_CONTENT)
          measure(
              View.MeasureSpec.makeMeasureSpec(800.dpToPx(), View.MeasureSpec.EXACTLY),
              View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
          )
          layout(0, 0, measuredWidth, measuredHeight)
      }
      val bmp = Bitmap.createBitmap(composeView.width, composeView.height, ARGB_8888)
      composeView.draw(Canvas(bmp))
      return bmp
  }
  ```
- 保存到 `context.cacheDir/share/poster-<uuid>.png`

**分享调用**(用 FileProvider):
```kotlin
val uri = FileProvider.getUriForFile(
    context, "${context.packageName}.fileprovider", posterFile
)
val intent = Intent(Intent.ACTION_SEND).apply {
    type = "image/png"
    putExtra(Intent.EXTRA_STREAM, uri)
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
}
context.startActivity(Intent.createChooser(intent, "分享"))
```

`AndroidManifest.xml` 需要 `<provider android:name="androidx.core.content.FileProvider" ...>` 和 `res/xml/file_paths.xml`(标准写法)。

**两处按钮行为**:
- 详情页 `TopAppBar` actions `IconButton(Icons.Default.Share)` → 调 `renderPoster` 后分享
- 预览页右上角 `IconButton` → 直接把已有 `composedImage` 保存到 `cacheDir` 后分享

---

## 9. API 配置(已同步)

- `ios/TravelTranslator/Info.plist` 的 `API_BASE_URL` = `http://192.168.1.148:8000`
- `ios/project.yml` 里 xcodegen 源 `API_BASE_URL` 也已对齐,防止下次 gen 覆盖回旧 IP
- `ios/TravelTranslator/Resources/Info.plist.template` 保持 `http://localhost:8000`(模板,不改)

### Android 对应
通常放 `android/app/build.gradle.kts` 的 `buildConfigField`:
```kotlin
buildConfigField("String", "API_BASE_URL", "\"http://192.168.1.148:8000\"")
```
加 `android:usesCleartextTraffic="true"` 或 `network_security_config.xml` 允许
局域网明文(生产版本应关掉)。真机调试时填 Mac 的局域网 IP,不能用 `localhost`。

---

## 10. iOS 特殊修复(Android 无需关心)

- `backend/app/services/vision_translate_service.py` 第 131 行 prompt 中把 ASCII 半角引号 `"项目"` 改成 `「项目」`,否则 Python 字符串被截断抛 `SyntaxError`(hotfix 41af4cb)
- `ios/TravelTranslator.xcodeproj/project.pbxproj` 因为历史原因没有 Resources build phase,Assets.xcassets 是手工注册的;以后加资源要么用 xcodegen 重生成,要么继续手改 pbxproj

---

## 附:推荐的 Android 实现顺序

1. **OCR + 后端联调**(ML Kit → 调用 `/vision-translate/stream` SSE),先跑通菜单翻译 golden path
2. **详情页**(顶部固定图 + 滚动列表)
3. **全屏预览 + 手势**(Compose `transformable`)
4. **历史页**(Room + 文件存储)
5. **分享**(仅标注图 → 合成长图,先做易做的)
6. **文案 / 配色 / 深色模式**对齐 iOS

每一步都可以单独 PR,后端完全复用,无需改动。
