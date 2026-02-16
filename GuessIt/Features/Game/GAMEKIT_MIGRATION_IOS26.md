# Game Center Integration - UIViewControllerRepresentable Approach

## Resumen

Game Center se integra usando `GKGameCenterViewController` envuelto en un `UIViewControllerRepresentable`, presentado via `.fullScreenCover`.

**No existe** un modificador nativo `.gameCenter(isPresented:)` en SwiftUI. La documentacion original de este archivo era incorrecta.

## Arquitectura

### GameCenterDashboardView (UIViewControllerRepresentable)

Wrapper minimo sobre `GKGameCenterViewController`:

```swift
struct GameCenterDashboardView: UIViewControllerRepresentable {
    let state: GKGameCenterViewControllerState

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(state: state)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }
    // ...
}
```

### GameCenterService

Propiedad `@Observable` controla la presentacion:

```swift
var isShowingGameCenter: Bool = false

func showDashboard() {
    guard isAuthenticated else { return }
    isShowingGameCenter = true
}
```

### GameView

Presenta via `.fullScreenCover`:

```swift
.fullScreenCover(isPresented: Binding(
    get: { env.gameCenterService.isShowingGameCenter },
    set: { env.gameCenterService.isShowingGameCenter = $0 }
)) {
    GameCenterDashboardView(state: .dashboard)
}
```

## Estados disponibles

| Estado | Descripcion |
|---|---|
| `.dashboard` | Dashboard principal |
| `.leaderboards` | Lista de leaderboards |
| `.achievements` | Lista de logros |
| `.localPlayerProfile` | Perfil del jugador |

## Autenticacion

Sin cambios. Usa `GKLocalPlayer.local.authenticateHandler` en `RootView.onAppear`.

## Fecha: 13 de febrero de 2026
