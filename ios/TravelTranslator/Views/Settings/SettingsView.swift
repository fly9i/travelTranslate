import SwiftUI

/// 设置页。
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("我的语言") {
                Picker("母语/地区", selection: $appState.userLocale) {
                    ForEach(UserLocales.all) { u in
                        Text("\(u.flag) \(u.name)").tag(u)
                    }
                }
            }
            Section("目的地") {
                Picker("当前目的地", selection: $appState.destination) {
                    ForEach(Destinations.all) { dest in
                        Text("\(dest.flag) \(dest.name)").tag(dest)
                    }
                }
            }
            Section("翻译选项") {
                Toggle("文化润色（LLM 地道化 + 文化提醒）", isOn: $appState.culturalPolish)
            }
            Section("服务") {
                LabeledContent("后端地址", value: APIConfig.baseURL.absoluteString)
            }
            Section("关于") {
                LabeledContent("应用", value: "TravelTranslator")
                LabeledContent("版本", value: "0.1.0")
            }
        }
        .navigationTitle("设置")
    }
}
