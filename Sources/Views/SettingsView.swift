import SwiftUI

struct SettingsView: View {
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @Environment(\.dismiss) private var dismiss
    @State private var revealKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if revealKey {
                                TextField("sk-ant-…", text: $apiKey)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("sk-ant-…", text: $apiKey)
                            }
                        }
                        Button {
                            revealKey.toggle()
                        } label: {
                            Image(systemName: revealKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Stored locally on this device. Sent only to api.anthropic.com.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
