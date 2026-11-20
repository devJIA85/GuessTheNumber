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
    private static let developerProfile = URL(string: "https://www.linkedin.com/in/jantolini")

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxLarge) {
                AboutProductHeader()

                Text("settings.about.description")
                    .foregroundStyle(.secondary)

                if let profile = Self.developerProfile {
                    Link(destination: profile) {
                        Label("settings.about.linkedin", systemImage: "person.crop.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 44)
                            .padding(.horizontal, AppTheme.Spacing.medium)
                    }
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }

                AboutDeveloperSignature()
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 480)
            .padding(AppTheme.Spacing.large)
            .frame(maxWidth: .infinity)
        }
        .background { FocusBackground() }
        .navigationTitle("settings.about")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
    }
}

private struct AboutProductHeader: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Image(decorative: "LatetBrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            Text("game.title")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .accessibilityAddTraits(.isHeader)
            Text("settings.about.subtitle")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
               let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                Text("settings.about.version \(version) \(build)")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.vertical, AppTheme.Spacing.small)
                    .background(.thinMaterial, in: Capsule())
            }
        }
    }
}

private struct AboutDeveloperSignature: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Image(decorative: "DeveloperLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 144)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("settings.about.developed_by")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
