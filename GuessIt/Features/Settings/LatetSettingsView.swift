import SwiftUI

enum LatetAppearance: String, CaseIterable {
    static let storageKey = "latetAppearance"

    case system
    case light
    case dark

    var title: LocalizedStringKey {
        switch self {
        case .system: "settings.appearance.system"
        case .light: "settings.appearance.light"
        case .dark: "settings.appearance.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct LatetSettingsView: View {
    @AppStorage(LatetAppearance.storageKey) private var appearance = LatetAppearance.system
    @State private var isTutorialPresented = false

    var body: some View {
        Form {
            Picker("settings.appearance", selection: $appearance) {
                ForEach(LatetAppearance.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            Button {
                isTutorialPresented = true
            } label: {
                Label("game.how_to_play", systemImage: "questionmark.circle")
            }
            NavigationLink(value: GameRoute.about) {
                Label("settings.about", systemImage: "info.circle")
            }
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
        .fullScreenCover(isPresented: $isTutorialPresented) {
            TutorialView(isPresented: $isTutorialPresented)
        }
    }
}

struct LatetAboutView: View {
    var body: some View {
        Form {
            Section("settings.developer") {
                Image(decorative: "DeveloperLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)
                    .frame(maxWidth: .infinity)
                Text(verbatim: "Juan Ignacio Antolini")
            }
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                LabeledContent("settings.version", value: version)
            }
        }
        .navigationTitle("settings.about")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
    }
}
