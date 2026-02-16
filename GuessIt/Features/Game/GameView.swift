//
//  GameView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import SwiftUI
import SwiftData
import GameKit
import UIKit

/// Pantalla principal del juego.
///
/// # Rol
/// - Es la vista raíz que se monta desde `GuessItApp`.
/// - Consume `GameActor` a través de `AppEnvironment`.
/// - Lee el estado persistido (SwiftData) con `@Query`.
struct GameView: View {

    // MARK: - Dependencies

    /// Acceso al composition root (actores y servicios de alto nivel).
    @Environment(\.appEnvironment) private var env

    // MARK: - SwiftData

    /// Partidas recientes ordenadas por fecha de creación.
    ///
    /// # Por qué filtramos en código y no en #Predicate
    /// - SwiftData no soporta comparaciones de enum en `#Predicate`
    ///   (error: "key path cannot refer to enum case").
    /// - La alternativa sería agregar un `stateRawValue: String` stored property
    ///   al modelo, pero requiere migración de SwiftData y es invasivo para el MVP.
    /// - Con un dataset pequeño (decenas de partidas), el filtrado en código es aceptable.
    @Query(
        sort: [SortDescriptor(\Game.createdAt, order: .reverse)]
    ) private var allGames: [Game]

    // MARK: - UI State

    /// Input del usuario (string crudo).
    @State private var guessText: String = ""

    /// Manejo simple de errores para mostrar en un alert.
    @State private var errorMessage: String?
    
    #if DEBUG
    /// Controla el alert de debug para revelar el secreto actual.
    /// - Why: facilita probar la UI de victoria sin resolver la partida.
    @State private var isDebugSecretPresented = false
    #endif
    
    // MARK: - Hint State
    
    /// Estado de carga de la pista AI.
    @State private var hintState: LoadState<HintOutput> = .empty
    
    /// Controla la presentación del sheet de pista.
    @State private var isHintPresented = false
    
    /// Task de generación de pista (para cancelar si se cierra el sheet).
    @State private var hintTask: Task<Void, Never>?
    
    /// Información de debug de la pista (solo DEBUG).
    ///
    /// # Por qué @State
    /// - Esta info se carga cada vez que se abre el sheet de pista.
    /// - Se actualiza con cada generación de pista.
    @State private var hintDebugInfo: HintDebugInfo? = nil
    
    /// Historial de pistas generadas en la partida actual (memoria local).
    /// - Why: permite mostrar pistas anteriores sin persistirlas en SwiftData.
    @State private var hintHistory: [HintHistoryEntry] = []

    /// Estado observable de la splash de victoria.
    /// - Why: permite coordinar presentación + haptic sin persistencia.
    @State private var victorySplash = VictorySplashState()
    
    /// Controla la presentación del tutorial.
    @State private var isTutorialPresented = false



    var body: some View {
        navigationContent
    }
    
    private var navigationContent: some View {
        NavigationStack {
            contentWithOverlay
                .task { await initializeGameIfNeeded() }
                .onChange(of: currentGame?.state) { _, newValue in
                    handleGameStateChange(newValue)
                }
                .onChange(of: currentGame?.id) { _, _ in
                    resetHintUIState()
                }
                .alert(
                    "Error",
                    isPresented: errorBinding,
                    actions: {
                        Button("OK", role: .cancel) { errorMessage = nil }
                    },
                    message: {
                        Text(errorMessage ?? "")
                    }
                )
                #if DEBUG
                .alert(
                    "Secreto actual",
                    isPresented: $isDebugSecretPresented,
                    actions: {
                        Button("Cerrar", role: .cancel) { isDebugSecretPresented = false }
                    },
                    message: {
                        Text(currentGame?.secret ?? "Sin partida")
                    }
                )
                #endif
                .toolbar {
                    leadingToolbarItems
                    trailingToolbarItems
                }
                .toolbarTitleDisplayMode(.inline)
                .sheet(isPresented: $isHintPresented, onDismiss: onHintDismiss) {
                    hintSheet
                }
                .fullScreenCover(isPresented: $isTutorialPresented) {
                    TutorialView(isPresented: $isTutorialPresented)
                }
                .fullScreenCover(isPresented: Binding(
                    get: { env.gameCenterService.isShowingGameCenter },
                    set: { env.gameCenterService.isShowingGameCenter = $0 }
                )) {
                    GameCenterDashboardView(state: .dashboard)
                }
        }
    }
    
    private var contentWithOverlay: some View {
        mainContent
            .overlay { victorySplashOverlay }
            .animation(.easeOut(duration: 0.2), value: victorySplash.isPresented)
            .navigationTitle("game.title")
            .navigationSubtitle(statusText)
            .tint(.appActionPrimary)
    }
    
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
    
    private func onHintDismiss() {
        hintTask?.cancel()
        hintTask = nil
    }
    
    // MARK: - Main Content Views
    
    private var mainContent: some View {
        ZStack {
            backgroundGradient
            scrollableContent
                .safeAreaInset(edge: .bottom) {
                    inputSection
                }
        }
    }
    
    private var backgroundGradient: some View {
        PremiumBackgroundGradient()
            .modernBackgroundExtension()
    }
    
    private var scrollableContent: some View {
        ScrollView {
            glassContainer {
                LazyVStack(spacing: AppTheme.Spacing.large) {
                    if let game = currentGame, game.state == .won {
                        VictorySectionView(game: game, onNewGame: startNewGame)
                    }
                    
                    if let game = currentGame {
                        HistorySectionView(game: game)
                    } else {
                        EmptyStateSectionView()
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.small)
                .padding(.vertical, 4)
            }
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 0) {
            if let game = currentGame {
                @Bindable var bindableGame = game
                
                if game.state == .inProgress {
                    GuessInputView(
                        guessText: $guessText,
                        game: bindableGame,
                        onDigitTap: handleDigitTap,
                        onSubmit: submit
                    )
                    .padding(.horizontal, AppTheme.Spacing.small)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                } else {
                    DisabledInputSectionView()
                        .padding(.horizontal, AppTheme.Spacing.small)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                }
            } else {
                GuessInputView(
                    guessText: $guessText,
                    game: nil,
                    onDigitTap: nil,
                    onSubmit: submit
                )
                .padding(.horizontal, AppTheme.Spacing.small)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
        .background {
            inputSectionBackground
        }
    }
    
    @ViewBuilder
    private var inputSectionBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .background(.ultraThinMaterial)
        } else {
            Color.appBackgroundPrimary.opacity(0.95)
        }
    }
    
    @ViewBuilder
    private var victorySplashOverlay: some View {
        if victorySplash.isPresented, let game = currentGame {
            VictorySplashView(
                secret: game.secret,
                attempts: game.attempts.count
            ) {
                handleVictorySplashDismiss()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }
    
    /// Maneja el dismiss de la splash de victoria y resetea el juego.
    /// - Why: centraliza la lógica para asegurar que siempre funcione correctamente.
    private func handleVictorySplashDismiss() {
        // 1. Cerrar la splash con animación
        withAnimation(.easeOut(duration: 0.2)) {
            victorySplash.dismiss()
        }
        
        // 2. Esperar a que la animación termine antes de iniciar nueva partida
        // Why: evita conflictos de estado durante la transición
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            startNewGame()
        }
    }
    
    // MARK: - Toolbar Items
    
    @ToolbarContentBuilder
    private var leadingToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if env.gameCenterService.isAuthenticated {
                Button {
                    env.gameCenterService.showDashboard()
                } label: {
                    Label("Game Center", systemImage: "gamecontroller.fill")
                        .labelStyle(.iconOnly)
                }
                .foregroundStyle(Color.appTextSecondary)
            }

            NavigationLink {
                HistoryView()
            } label: {
                Label("Historial", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.iconOnly)
            }
            .foregroundStyle(Color.appTextSecondary)

            NavigationLink {
                StatsView()
            } label: {
                Label("Estadísticas", systemImage: "chart.bar.fill")
                    .labelStyle(.iconOnly)
            }
            .foregroundStyle(Color.appTextSecondary)

            NavigationLink {
                DailyChallengeView()
            } label: {
                Label("Desafío Diario", systemImage: "calendar")
                    .labelStyle(.iconOnly)
            }
            .foregroundStyle(Color.appTextSecondary)
        }
    }
    
    @ToolbarContentBuilder
    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let game = currentGame, game.state == .inProgress {
                Button {
                    prepareHintPresentation()
                    isHintPresented = true
                } label: {
                    Label("Pista", systemImage: "lightbulb")
                        .labelStyle(.iconOnly)
                }
                .foregroundStyle(Color.appTextSecondary)
            }
            
            Button {
                isTutorialPresented = true
            } label: {
                Label("Cómo jugar", systemImage: "questionmark.circle")
                    .labelStyle(.iconOnly)
            }
            .foregroundStyle(Color.appTextSecondary)

            Button {
                startNewGame()
            } label: {
                Label("Reiniciar", systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
            }
            .foregroundStyle(Color.appTextSecondary)

            #if DEBUG
            Button {
                isDebugSecretPresented = true
            } label: {
                Label("Debug Secreto", systemImage: "eye")
                    .labelStyle(.iconOnly)
            }
            .foregroundStyle(Color.appTextSecondary)
            #endif
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleDigitTap(_ digit: Int) {
        if guessText.count < 5 {
            guessText.append("\(digit)")
            
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    private func initializeGameIfNeeded() async {
        if currentGame == nil {
            do {
                try await env.gameActor.resetGame()
                
                // Iniciar actividad de Game Center (Continue Playing)
                await MainActor.run {
                    env.activityService.startActivity(type: .mainGame)
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
    
    private func handleGameStateChange(_ newValue: GameState?) {
        if newValue == .won {
            withAnimation(.easeOut(duration: 0.2)) {
                victorySplash.present()
            }
            triggerVictoryHapticIfNeeded()
            
            // Finalizar actividad con éxito
            env.activityService.endActivity()
            
            // Enviar puntuación a leaderboards
            if let game = currentGame {
                Task {
                    await env.leaderboardService.submitScore(attempts: game.attempts.count)
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                victorySplash.dismiss()
            }
            victorySplash.resetHaptic()
        }
        if newValue == .inProgress {
            resetHintUIState()
            
            // Iniciar nueva actividad
            env.activityService.startActivity(type: .mainGame)
        }
    }

    // MARK: - Modular Subviews (DRY + Arquitectura Limpia)
    // Las subvistas están extraídas al final del archivo para mantener el body limpio
    // - Why: mejora la legibilidad y permite reutilizar componentes
    // - Principio: cada subvista encapsula su propia lógica visual

    // MARK: - Helpers

    /// Envuelve el contenido en un GlassEffectContainer en iOS 26+.
    /// - Why: Apple recomienda usar container para mejor rendimiento con múltiples efectos
    /// - Fallback: En iOS <26 retorna el contenido sin wrapper
    @ViewBuilder
    private func glassContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: Usar GlassEffectContainer para optimizar rendimiento
            // - spacing: controla cuándo los efectos comienzan a blend
            // - AppTheme.Spacing.medium (16pt) permite que efectos separados no se mezclen
            GlassEffectContainer(spacing: AppTheme.Spacing.medium) {
                content()
            }
        } else {
            // iOS 13-25: No hay container, renderizar contenido directamente
            content()
        }
    }

    /// La partida actual.
    /// - Returns: la partida en progreso si existe, o la más reciente ganada si no hay ninguna en progreso.
    /// - Why: después de ganar y crear una nueva, queremos mostrar la nueva (inProgress), no la ganada.
    private var currentGame: Game? {
        // Prioridad 1: partida en progreso (la más reciente si hay varias)
        if let inProgress = allGames.first(where: { $0.state == .inProgress }) {
            return inProgress
        }
        // Prioridad 2: partida ganada (para mostrar la splash antes de crear nueva)
        return allGames.first { $0.state == .won }
    }

    /// Texto de estado, basado en la partida persistida.
    private var statusText: String {
        guard let game = currentGame else {
            return String(localized: "game.status.none")
        }

        switch game.state {
        case .inProgress:
            return String(localized: "game.status.in_progress")
        case .won:
            return String(localized: "game.status.won")
        case .abandoned:
            return String(localized: "game.status.abandoned")
        }
    }

    /// Inicia una nueva partida.
    /// - Why: resetea el juego y limpia el estado UI local.
    private func startNewGame() {
        // Cerramos la splash antes de resetear para evitar el flash de “ganaste”.
        victorySplash.dismiss()
        
        Task(name: "StartNewGame") {
            do {
                try await env.gameActor.resetGame()
                // Limpiar el estado de UI solo después de que el reset sea exitoso
                await MainActor.run {
                    guessText = ""
                    resetHintUIState()
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    print("❌ Error al resetear juego: \(error)")
                }
            }
        }
    }

    /// Envía el guess al actor del dominio.
    /// - Note: hacemos `Task` porque cruzamos aislamiento de actor.
    /// - Why no se guarda lastResult: la lista de intentos ya muestra el historial completo.
    private func submit(_ guess: String) {
        Task(name: "SubmitGuess") {
            do {
                _ = try await env.gameActor.submitGuess(guess)
                guessText = ""
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Dispara el haptic de éxito una sola vez por victoria.
    /// - Why: refuerza el feedback sin ser intrusivo.
    private func triggerVictoryHapticIfNeeded() {
        guard !victorySplash.didFireHaptic else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        victorySplash.markHapticFired()
    }
    
    // MARK: - Hint Sheet
    
    /// Vista del sheet de pista.
    ///
    /// # Estados
    /// - loading: generando la pista (muestra spinner diferido).
    /// - loaded: pista disponible (muestra texto).
    /// - failure: error al generar (muestra mensaje de error).
    /// - empty: estado inicial (no debería verse, genera automáticamente).
    private var hintSheet: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundPrimary
                    .ignoresSafeArea()

                Group {
                    switch hintState {
                    case .loading:
                        AppCard(title: "Pista inteligente") {
                            VStack(spacing: AppTheme.Spacing.medium) {
                                // Spinner diferido: evita parpadeos si la pista responde rápido
                                // Por qué 300ms: balance entre evitar flicker y no hacer esperar al usuario
                                // Por qué hintState.isLoading: el spinner debe aparecer/desaparecer según el estado real
                                DeferredProgressView(
                                    isActive: hintState.isLoading,
                                    delay: .milliseconds(300)
                                )
                                .frame(height: 60)
                                
                                Text("Generando pista...")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(AppTheme.Spacing.medium)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    case .loaded(let output):
                        ScrollView {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                                AppCard(title: "Pista inteligente") {
                                    Text(output.text)
                                        .font(.body)
                                        .foregroundStyle(Color.appTextPrimary)
                                        .accessibilityLabel("Pista: \(output.text)")
                                }
                                
                                if hintHistory.count > 1 {
                                    AppCard(title: "Pistas anteriores") {
                                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                                            // Mostramos las pistas previas en orden descendente (mas recientes primero).
                                            ForEach(hintHistory.dropLast().reversed()) { entry in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(entry.title)
                                                        .font(.caption)
                                                        .foregroundStyle(Color.appTextSecondary)
                                                    Text(entry.text)
                                                        .foregroundStyle(Color.appTextPrimary)
                                                }
                                                .accessibilityElement(children: .combine)
                                                .accessibilityLabel("Pista anterior: \(entry.text)")
                                            }
                                        }
                                    }
                                }
                                
                                #if DEBUG
                                // Sección de debug (solo visible en DEBUG builds)
                                if let debugInfo = hintDebugInfo {
                                    AppCard(title: "Debug") {
                                        debugSection(debugInfo)
                                    }
                                }
                                #endif
                            }
                            .padding(AppTheme.Spacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                    case .failure(let error):
                        AppCard(title: "Pista inteligente") {
                            VStack(spacing: AppTheme.Spacing.medium) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.appTextSecondary)
                                
                                Text(errorMessageForHint(error))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(AppTheme.Spacing.medium)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    case .empty:
                        // Estado inicial, trigger generación
                        Color.clear
                            .onAppear {
                                generateHint()
                            }
                    }
                }
            }
            .navigationTitle("Pista Inteligente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        isHintPresented = false
                    }
                }
            }
        }
        .tint(.appActionPrimary)
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Hint Helpers
    
    /// Genera una pista para la partida actual.
    ///
    /// # Flujo
    /// 1. Obtener snapshot de la partida actual.
    /// 2. Convertir snapshot a HintInput.
    /// 3. Llamar HintService.generateHint.
    /// 4. Actualizar hintState con el resultado.
    ///
    /// # Cancelación
    /// - La task se guarda en hintTask para poder cancelarla si se cierra el sheet.
    private func generateHint() {
        // Cancelar task anterior si existe
        hintTask?.cancel()
        
        // Setear estado loading
        hintState = .loading
        
        // Crear nueva task
        hintTask = Task(name: "GenerateHint") {
            do {
                // 1. Obtener ID de la partida actual
                guard let gameID = try await env.modelActor.fetchInProgressGameID() else {
                    hintState = .failure(HintError.unavailable)
                    return
                }
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 2. Obtener snapshot completo
                let snapshot = try await env.modelActor.fetchGameDetailSnapshot(gameID: gameID)
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 3. Convertir snapshot a HintInput
                let hintInput = makeHintInput(from: snapshot)
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 4. Generar pista
                let output = try await env.hintService.generateHint(input: hintInput)
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 5. Registrar pista en historial local antes de mostrarla.
                hintHistory.append(HintHistoryEntry(text: output.text, createdAt: Date()))
                
                // 6. Actualizar estado (en MainActor)
                hintState = .loaded(output)
                
                // 7. Cargar debug info (solo en DEBUG)
                #if DEBUG
                hintDebugInfo = await env.hintService.debugInfo()
                #endif
                
            } catch is CancellationError {
                // Task fue cancelada, no hacer nada
                return
            } catch {
                // Error al generar pista
                hintState = .failure(error)
            }
        }
    }
    
    /// Resetea el estado de la pista y cancela cualquier generación en curso.
    /// - Why: evita que el texto o loading de una partida anterior contamine la nueva.
    private func resetHintUIState() {
        hintTask?.cancel()
        hintTask = nil
        hintState = .empty
        hintDebugInfo = nil
        hintHistory.removeAll()
        isHintPresented = false
    }

    /// Prepara el estado de la pista para generar una nueva al abrir el sheet.
    /// - Why: si el usuario pide otra pista, no debe quedarse con la anterior.
    private func prepareHintPresentation() {
        hintTask?.cancel()
        hintTask = nil
        hintState = .empty
        hintDebugInfo = nil
    }

    /// Modelo liviano para renderizar historial de pistas en la UI.
    /// - Why: evita depender de SwiftData y mantiene el estado solo en memoria.
    private struct HintHistoryEntry: Identifiable {
        let id = UUID()
        let text: String
        let createdAt: Date

        var title: String {
            // Mostramos una etiqueta simple para darle contexto temporal sin persistencia.
            "Pista \(formattedTime)"
        }

        private static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter
        }()

        private var formattedTime: String {
            Self.timeFormatter.string(from: createdAt)
        }
    }
    
    /// Convierte un GameDetailSnapshot a HintInput.
    ///
    /// # Por qué este mapper
    /// - HintInput es Sendable y no depende de SwiftData.
    /// - GameDetailSnapshot ya es Sendable y tiene todos los datos necesarios.
    /// - Este mapper mantiene la separación de concerns (UI → DTO → Service).
    private func makeHintInput(from snapshot: GameDetailSnapshot) -> HintInput {
        let attempts = snapshot.attempts.map { attempt in
            HintAttempt(
                guess: attempt.guess,
                good: attempt.good,
                fair: attempt.fair,
                isPoor: attempt.isPoor,
                isRepeated: attempt.isRepeated
            )
        }
        
        let digitNotes = snapshot.digitNotes.map { note in
            HintDigitNote(
                digit: note.digit,
                mark: note.mark
            )
        }
        
        return HintInput(
            gameID: snapshot.id,
            attempts: attempts,
            digitNotes: digitNotes
        )
    }
    
    /// Mapea errores de hint a mensajes user-friendly.
    ///
    /// # Por qué este helper
    /// - Los errores técnicos (HintError) no son buenos mensajes para el usuario.
    /// - Centralizamos la lógica de mensajes en un solo lugar.
    private func errorMessageForHint(_ error: Error) -> String {
        if let hintError = error as? HintError {
            switch hintError {
            case .unavailable:
                return "Las pistas no están disponibles en este dispositivo. Se requiere Apple Intelligence."
            case .generationFailed:
                return "No se pudo generar una pista en este momento. Intentá de nuevo más tarde."
            case .unsafeOutput:
                return "La pista generada no cumplió con las reglas de seguridad. Intentá de nuevo."
            case .timedOut:
                return "La generación de la pista tardó demasiado. Intentá de nuevo."
            case .rateLimited:
                return "Alcanzaste el límite de pistas por sesión. Reiniciá la app para más pistas."
            }
        }
        return "Ocurrió un error inesperado al generar la pista."
    }
    
    // MARK: - Debug UI (solo DEBUG)
    
    #if DEBUG
    /// Sección de debug con telemetría del HintService.
    ///
    /// # Por qué solo DEBUG
    /// - Esta info solo es útil para QA y desarrollo.
    /// - No debe mostrarse en Release builds.
    ///
    /// # Contenido
    /// - Total de requests de pistas en esta sesión.
    /// - Engine usado (apple o fallback).
    /// - Último error (si hubo).
    @ViewBuilder
    private func debugSection(_ info: HintDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 8)
            
            Text("Debug Info (solo visible en DEBUG)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appTextSecondary)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Requests:")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                    Text("\(info.requestCount)")
                        .font(.caption)
                        .fontDesign(.monospaced)
                }
                
                if let engine = info.lastEngineUsed {
                    HStack {
                        Text("Engine:")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                        Text(engine)
                            .font(.caption)
                            .fontDesign(.monospaced)
                    }
                }
                
                if let error = info.lastErrorDescription {
                    HStack(alignment: .top) {
                        Text("Last error:")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                        Text(error)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(12)
            .background(Color.appTextSecondary.opacity(0.12))
            .cornerRadius(8)
        }
    }
    #endif
}

// MARK: - Modular Subviews (Arquitectura Limpia + DRY)
// Subvistas extraídas para mejorar la legibilidad y reutilización

/// Sección de Input deshabilitada cuando la partida terminó.
///
/// # Por qué existe
/// - Feedback claro cuando no se puede continuar jugando
/// - Estilo más sutil (ultraThin) para indicar estado inactivo
private struct DisabledInputSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text(String(localized: "game.input.title", defaultValue: "Tu intento"))
                .font(AppTheme.Typography.headline())
                .foregroundStyle(Color.appTextSecondary)
            
            HStack(spacing: AppTheme.Spacing.small) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.appTextSecondary)
                    .font(.title3)
                
                Text("game.input.disabled")
                    .font(AppTheme.Typography.body())
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .glassCard(material: .ultraThin)  // Material más sutil para estado inactivo
    }
}

/// Sección de Estado Vacío cuando no hay partida en progreso.
///
/// # Por qué existe
/// - Feedback claro de que la app está esperando la primera acción
/// - Usa SF Symbol para comunicación visual rápida
private struct EmptyStateSectionView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "play.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.appTextSecondary.opacity(0.6))
            
            Text("Ingresá tu primer intento para comenzar")
                .font(AppTheme.Typography.body())
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .glassCard(material: .ultraThin)
    }
}

/// Sección de Victoria con celebración y CTA.
///
/// # Diseño
/// - Estilo vibrante para reforzar el éxito
/// - Botón prominent para guiar a la siguiente acción
/// - Tipografía bold para jerarquizar el mensaje de victoria
///
/// # Por qué existe
/// - Proporciona feedback celebratorio claro
/// - Ofrece camino evidente para continuar jugando
private struct VictorySectionView: View {
    let game: Game
    let onNewGame: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: AppTheme.Spacing.large) {
            // Título celebratorio con emoji
            // Why: el emoji refuerza el sentimiento positivo sin necesitar animaciones complejas
            Text("game.victory.title")
                .font(AppTheme.Typography.title())
                .foregroundStyle(Color.appActionPrimary)
            
            // Métricas del juego
            VStack(spacing: AppTheme.Spacing.small) {
                MetricRow(label: String(localized: "game.victory.secret"), value: game.secret, isMonospaced: true)
                MetricRow(label: String(localized: "game.victory.attempts"), value: "\(game.attempts.count)", isMonospaced: false)
            }
            .padding(AppTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.appBackgroundSecondary.opacity(0.5))
            )
            
            // CTA: Nueva partida
            // Why: botón prominent con ícono para máxima affordance
            // iOS 26+: Usa GlassProminentButtonStyle (Liquid Glass)
            // iOS 13-25: Usa .borderedProminent (fallback)
            Button(action: onNewGame) {
                Label("Nueva partida", systemImage: "plus.circle.fill")
                    .font(AppTheme.Typography.headline())
                    .frame(maxWidth: .infinity)
            }
            .modernProminentButton()  // Helper que detecta iOS 26+ automáticamente
            .tint(.appActionPrimary)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .glassCard(tintColor: .appActionPrimary)  // Tint para dar énfasis celebratorio
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ganaste. Secreto: \(game.secret). Intentos: \(game.attempts.count).")
    }
}

/// Row helper para mostrar métricas key-value.
/// - Why DRY: evita duplicar el layout de HStack + labels en VictorySectionView
private struct MetricRow: View {
    let label: String
    let value: String
    let isMonospaced: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.body())
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.headline())
                .fontDesign(isMonospaced ? .monospaced : .rounded)
                .foregroundStyle(Color.appTextPrimary)
        }
    }
}

/// Sección de Historial de Intentos con ContentUnavailableView.
///
/// # Diseño
/// - Si está vacío: muestra ContentUnavailableView bonito con SF Symbol
/// - Si tiene intentos: lista scrolleable limitada a 5 intentos visibles
/// - Cada intento se renderiza en una mini-card con AttemptRowView
///
/// # Por qué existe
/// - Encapsula la lógica de renderizado del historial
/// - ContentUnavailableView mejora la UX cuando no hay datos
/// - Mantiene el código DRY (no repetimos el layout de intentos)
private struct HistorySectionView: View {
    let game: Game
    
    private var sortedAttempts: [Attempt] {
        game.attempts.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            // Header con mejor contraste
            Text("Historial")
                .font(AppTheme.Typography.headline())
                .foregroundStyle(Color.primary)
            
            // Contenido: ContentUnavailableView si vacío, lista si hay intentos
            if sortedAttempts.isEmpty {
                // Estado vacío con ContentUnavailableView estilo iOS 18
                // Why: comunica claramente que no hay datos sin parecer un error
                // NOTA: Usamos frame con altura fija para evitar que ocupe demasiado espacio
                ContentUnavailableView {
                    Label("Sin intentos", systemImage: "clock.badge.questionmark")
                        .font(.subheadline)  // Reducimos tamaño para compactar
                        .foregroundStyle(Color.primary)
                } description: {
                    Text("Tus intentos aparecerán aquí")
                        .font(AppTheme.Typography.caption())
                        .foregroundStyle(Color.secondary)
                }
                .frame(height: 100)  // Altura fija compacta para no dominar la pantalla
            } else {
                // Lista scrolleable de intentos
                // Why: limitar altura a ~5 intentos evita que la sección domine la pantalla
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.small) {
                        ForEach(sortedAttempts) { attempt in
                            AttemptRowView(attempt: attempt)
                                .padding(AppTheme.Spacing.small)
                                // NUEVO: Fondo ultra-sutil que mantiene glassmorphism
                                // - Why: el fondo anterior (opacity 0.6) era muy opaco
                                // - Ahora usa opacity 0.15 para máxima transparencia
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                                        .strokeBorder(Color.appBorderSubtle.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                    }
                }
                .frame(maxHeight: 220)  // ~5 intentos visibles
            }
        }
        .glassCard()
    }
}

// MARK: - CompactDeductionBoardView y CompactDigitCell eliminados
// Reemplazados por CollapsibleBoardHeader y AdaptiveDigitCell.
// - CollapsibleBoardHeader: header colapsable con grilla 2×5 adaptativa.
// - AdaptiveDigitCell: celda que interpola dimensiones según scroll offset.
// Ver CollapsibleBoardHeader.swift y AdaptiveDigitCell.swift.

