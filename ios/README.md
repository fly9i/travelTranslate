# TravelTranslator iOS

Swift 5.9 + SwiftUI 实现的旅行沟通助手 iOS 客户端。

## 目录

```
ios/
├── Package.swift                      # SwiftPM manifest（也可用 Xcode 打开）
├── TravelTranslator/
│   ├── App/                           # App 入口
│   ├── Models/                        # 数据模型
│   ├── Views/                         # SwiftUI 视图
│   ├── Services/                      # 网络/语音/OCR 服务
│   ├── Persistence/                   # 本地持久化
│   └── Resources/                     # 资源（短语包等）
```

## 运行

1. 用 Xcode 15+ 打开 `Package.swift`（或将源码拖入一个新的 iOS App 项目）
2. 在 `Services/APIConfig.swift` 修改 `baseURL` 指向后端服务地址
3. Build & Run，最低支持 iOS 17

## 配置

后端地址从 `Info.plist` 的 `API_BASE_URL` 读取（见 `APIConfig.swift`），
开发时也可在 Scheme 环境变量中覆盖为 `http://localhost:8000`。

**不要把 API Key 硬编码到代码中**，翻译引擎 API Key 由后端配置。
