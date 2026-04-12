# TravelTranslator iOS

Swift 5.9 + SwiftUI 实现的旅行沟通助手 iOS 客户端。

## 目录

```
ios/
├── project.yml                        # XcodeGen 项目描述（编辑这个，再 regenerate）
├── TravelTranslator.xcodeproj         # 由 xcodegen 生成，可直接用 Xcode 打开运行
├── Package.swift                      # SwiftPM manifest（可选，作为库复用）
├── TravelTranslator/
│   ├── App/                           # App 入口
│   ├── Models/                        # 数据模型
│   ├── Views/                         # SwiftUI 视图
│   ├── Services/                      # 网络/语音/OCR 服务
│   ├── Info.plist                     # 由 xcodegen 从 project.yml 生成
│   └── Resources/                     # 资源（短语包等）
```

## 运行

1. 用 Xcode 15+ 打开 `ios/TravelTranslator.xcodeproj`
2. 选中 `TravelTranslator` target → **Signing & Capabilities** 选你的开发者 Team，
   `PRODUCT_BUNDLE_IDENTIFIER` 改成你自己的唯一值（例如 `com.<你的名字>.traveltranslator`）
3. 顶栏 destination 选你的 iPhone → ⌘R
4. 真机首次运行需在 **设置 → 通用 → VPN 与设备管理** 信任开发者证书

> 真机调试时 `API_BASE_URL` 不能写 `localhost`，要填 Mac 的局域网 IP
> （例如 `http://192.168.x.x:8000`），手机和 Mac 保持同一 Wi-Fi。

## 修改项目配置

项目文件由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成。
要新增源码目录、修改 Bundle ID、调整权限描述等，**编辑 `project.yml` 然后重新生成**：

```bash
brew install xcodegen    # 第一次
cd ios && xcodegen generate
```

## 配置

后端地址从 `Info.plist` 的 `API_BASE_URL` 读取（见 `APIConfig.swift`），
开发时也可在 Scheme 环境变量中覆盖为 `http://localhost:8000`。

**不要把 API Key 硬编码到代码中**，翻译引擎 API Key 由后端配置。
