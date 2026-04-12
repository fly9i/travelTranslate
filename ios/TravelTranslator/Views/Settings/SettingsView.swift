import SwiftUI

/// 设置页。
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("目的地") {
                Picker("当前目的地", selection: Binding(
                    get: { appState.destination },
                    set: { appState.destination = $0 }
                )) {
                    ForEach(Destinations.all) { dest in
                        Text("\(dest.flag) \(dest.name)").tag(dest)
                    }
                }
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
