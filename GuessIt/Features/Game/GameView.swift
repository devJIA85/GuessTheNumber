//
//  GameView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import SwiftUI

/// Pantalla principal del juego.
///
/// # Rol
/// - Es la vista raíz que se monta desde `GuessItApp`.
/// - Consume `GameActor` a través de `AppEnvironment`.
/// - Renderiza un único snapshot explícito del juego actual.
@MainActor
struct GameView: View {

    // MARK: - Dependencies

    /// Acceso al composition root (actores y servicios de alto nivel).
    @Environment(\.appEnvironment) private var env

    // MARK: - UI State

    /// Store observable del flujo principal: dueño del snapshot de partida y del error.
    /// - Why: separa la orquestación (carga/submit/reset/notas) de la vista declarativa.
    @State private var vm = GameViewModel()

    /// Input del usuario (string crudo).
    @State private var guessText: String = ""
    
    #if DEBUG
    /// Controla el alert de debug para revelar el secreto actual.
    /// - Why: facilita probar la UI de victoria sin resolver la partida.
    @State private var isDebugSecretPresented = false
    @State private var debugSecretValue: String?
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
                .task {
                    vm.configure(env: env)
                    await vm.initialize()
                }
                .onChange(of: vm.currentGame?.state) { _, newValue in
                    handleGameStateChange(newValue)
                }
                .onChange(of: vm.currentGame?.id) { _, _ in
                    resetHintUIState()
                }
                .alert(
                    "Error",
                    isPresented: errorBinding,
                    actions: {
                        Button("OK", role: .cancel) { vm.errorMessage = nil }
                    },
                    message: {
                        Text(vm.errorMessage ?? "")
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
                        Text(debugSecretValue ?? "Sin partida")
                    }
                )
                #endif
                .sheet(isPresented: $isHintPresented, onDismiss: onHintDismiss) {
                    hintSheet
                }
                .fullScreenCover(isPresented: $isTutorialPresented) {
                    TutorialView(isPresented: $isTutorialPresented)
                }
        }
    }
    
    private var contentWithOverlay: some View {
        mainContent
            .overlay { victorySplashOverlay }
            .animation(.easeOut(duration: 0.2), value: victorySplash.isPresented)
            // La barra de navegación se oculta: las acciones viven en una fila propia
            // de íconos de línea (topActionsRow) y el badge de Game Center ocupa la
            // esquina superior izquierda vía GKAccessPoint (sistema).
            .toolbar(.hidden, for: .navigationBar)
            .tint(.appActionPrimary)
            // "Focus" es una estética siempre oscura: forzamos dark para que el status
            // bar y los acentos adaptativos resuelvan a sus variantes dark.
            .preferredColorScheme(.dark)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }
    
    private func onHintDismiss() {
        hintTask?.cancel()
        hintTask = nil
    }
    
    // MARK: - Main Content Views
    
    private var mainContent: some View {
        ZStack {
            FocusBackground()
            VStack(spacing: 0) {
                topActionsRow
                scrollableContent
            }
            .safeAreaInset(edge: .bottom) {
                inputSection
            }
        }
    }

    // MARK: - Top Actions

    /// Fila superior de acciones: íconos de línea livianos a la derecha (sin pills).
    /// El badge de Game Center vive en la esquina izquierda vía `GKAccessPoint`.
    private var topActionsRow: some View {
        HStack(spacing: 22) {
            Spacer()

            NavigationLink { HistoryView() } label: {
                actionIcon("clock.arrow.circlepath", label: "Historial")
            }
            NavigationLink { StatsView() } label: {
                actionIcon("chart.bar.fill", label: "Estadísticas")
            }
            NavigationLink { DailyChallengeView() } label: {
                actionIcon("calendar", label: "Desafío Diario")
            }

            if let game = vm.currentGame, game.state == .inProgress {
                Button {
                    prepareHintPresentation()
                    isHintPresented = true
                } label: {
                    actionIcon("lightbulb", label: "Pista")
                }
            }

            Menu {
                Button {
                    isTutorialPresented = true
                } label: {
                    Label("game.how_to_play", systemImage: "questionmark.circle")
                }
                Button {
                    startNewGame()
                } label: {
                    Label("game.reset", systemImage: "arrow.counterclockwise")
                }
                #if DEBUG
                Button {
                    revealDebugSecret()
                } label: {
                    Label("Debug Secreto", systemImage: "eye")
                }
                #endif
            } label: {
                actionIcon("ellipsis", label: "Más")
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.top, AppTheme.Spacing.small)
    }

    /// Ícono de acción de la barra superior: línea liviana, sin contenedor.
    private func actionIcon(_ systemName: String, label: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(Color.white.opacity(0.8))
            .frame(width: 30, height: 34)
            .contentShape(Rectangle())
            .accessibilityLabel(label)
    }

    private var scrollableContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                gameHeader

                if let game = vm.currentGame {
                    if let last = latestAttempt(in: game) {
                        LastAttemptCard(attempt: last)
                    }

                    if game.state == .won {
                        VictorySectionView(game: game, onNewGame: startNewGame)
                    }

                    attemptsHistory(for: game)

                    // Aún sin intentos: guía al primer movimiento en vez de dejar un hueco.
                    if game.attempts.isEmpty {
                        EmptyStateSectionView()
                    }
                } else {
                    EmptyStateSectionView()
                }
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.top, AppTheme.Spacing.small)
            .padding(.bottom, AppTheme.Spacing.medium)
        }
    }

    // MARK: - Header

    /// Header "Focus": marca + título grande a la izquierda, contador de intentos a la derecha.
    private var gameHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("game.title")
                    .focusSectionLabel()
                Text("game.header.title")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppTheme.Spacing.small)

            attemptsCounter
        }
        .padding(.top, AppTheme.Spacing.small)
    }

    /// Contador de intentos (sin tope: el juego principal no limita intentos).
    private var attemptsCounter: some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", vm.currentGame?.attempts.count ?? 0))
                .focusMonoDigits(size: 30, weight: .heavy, tracking: 1)
                .foregroundStyle(Color.appActionPrimary)
            Text("common.attempts")
                .focusSectionLabel()
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .focusCard(padding: 0)
        .frame(minWidth: 96)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(vm.currentGame?.attempts.count ?? 0) \(String(localized: "common.attempts"))"))
    }

    // MARK: - History

    /// Intento más reciente del snapshot (el destacado en la card "Último intento").
    private func latestAttempt(in game: GameDetailSnapshot) -> AttemptSnapshot? {
        game.attempts.max { $0.createdAt < $1.createdAt }
    }

    /// Historial compacto: filas con guess mono + badges, separadas por línea tenue.
    /// - Excluye el intento más reciente (ya destacado arriba en "Último intento").
    @ViewBuilder
    private func attemptsHistory(for game: GameDetailSnapshot) -> some View {
        let rest = game.attempts
            .sorted { $0.createdAt > $1.createdAt }
            .dropFirst()  // el primero es el "último intento" destacado

        if !rest.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rest.enumerated()), id: \.element.id) { index, attempt in
                    if index > 0 {
                        Divider()
                            .overlay(Color.white.opacity(0.06))
                    }
                    AttemptRowView(snapshot: attempt)
                        .padding(.vertical, AppTheme.Spacing.small)
                }
            }
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 0) {
            if let game = vm.currentGame {
                if game.state == .inProgress {
                    GuessInputView(
                        guessText: $guessText,
                        game: game,
                        onDigitTap: handleDigitTap,
                        onCycleDigitMark: cycleDigitMark,
                        onSetDigitMark: setDigitMark,
                        onResetBoard: resetDigitBoard,
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

    /// Fondo del dock: **opaco** para ocluir limpio el historial que scrollea por detrás
    /// (antes era translúcido y se leía "a través"). Hairline arriba + sombra hacia arriba.
    private var inputSectionBackground: some View {
        AppTheme.Focus.background
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
            .shadow(color: .black.opacity(0.6), radius: 12, y: -8)
    }
    
    @ViewBuilder
    private var victorySplashOverlay: some View {
        if victorySplash.isPresented, let game = vm.currentGame {
            VictorySplashView(
                secret: game.secret ?? "",
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
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            startNewGame()
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleDigitTap(_ digit: Int) {
        if guessText.count < 5 {
            guessText.append("\(digit)")

            HapticFeedbackManager.keypadTap()
        }
    }
    
    private func handleGameStateChange(_ newValue: GameState?) {
        if newValue == .won {
            withAnimation(.easeOut(duration: 0.2)) {
                victorySplash.present()
            }
            triggerVictoryHapticIfNeeded()

            // Enviar puntuación a leaderboards
            if let game = vm.currentGame {
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
        }
    }

    // MARK: - Modular Subviews (DRY + Arquitectura Limpia)
    // Las subvistas están extraídas al final del archivo para mantener el body limpio
    // - Why: mejora la legibilidad y permite reutilizar componentes
    // - Principio: cada subvista encapsula su propia lógica visual

    // MARK: - Helpers

    /// Inicia una nueva partida y limpia el estado de UI local solo si el reinicio fue exitoso.
    /// - Why: la orquestación (reset + reload) vive en la VM; la vista solo limpia su input/hint.
    private func startNewGame() {
        // Cerramos la splash antes de resetear para evitar el flash de “ganaste”.
        victorySplash.dismiss()

        Task { @MainActor in
            if await vm.startNewGame() {
                guessText = ""
                resetHintUIState()
            }
        }
    }

    /// Envía el guess al dominio (vía VM) y limpia el input solo si se procesó sin error.
    private func submit(_ guess: String) {
        Task { @MainActor in
            if await vm.submitGuess(guess) {
                guessText = ""
            }
        }
    }

    /// Cicla la marca de un dígito (delegado en la VM).
    private func cycleDigitMark(_ digit: Int) {
        Task { @MainActor in await vm.cycleDigitMark(digit) }
    }

    /// Establece una marca puntual (delegado en la VM).
    private func setDigitMark(_ digit: Int, _ mark: DigitMark) {
        Task { @MainActor in await vm.setDigitMark(digit, mark) }
    }

    /// Resetea el tablero de notas (delegado en la VM).
    private func resetDigitBoard() {
        Task { @MainActor in await vm.resetDigitBoard() }
    }

    /// Dispara el haptic de éxito una sola vez por victoria.
    /// - Why: refuerza el feedback sin ser intrusivo.
    private func triggerVictoryHapticIfNeeded() {
        guard !victorySplash.didFireHaptic else { return }
        HapticFeedbackManager.victory()
        victorySplash.markHapticFired()
    }

    #if DEBUG
    /// Carga el secreto actual bajo demanda para el alert de debug.
    private func revealDebugSecret() {
        Task { @MainActor in
            if let secret = await vm.debugSecret() {
                debugSecretValue = secret
                isDebugSecretPresented = true
            }
        }
    }
    #endif
    
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
        hintTask = Task(name: "GenerateHint") { @MainActor in
            do {
                // 1. Usar el snapshot actual como fuente de verdad de la pantalla.
                guard let currentGame = vm.currentGame, currentGame.state == .inProgress else {
                    hintState = .failure(HintError.unavailable)
                    return
                }
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 2. Convertir snapshot a HintInput
                let hintInput = makeHintInput(from: currentGame)
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 3. Generar pista
                let output = try await env.hintService.generateHint(input: hintInput)
                
                // Check cancelación
                try Task.checkCancellation()
                
                // 4. Registrar pista en historial local antes de mostrarla.
                hintHistory.append(HintHistoryEntry(text: output.text, createdAt: Date()))
                hintState = .loaded(output)
                
                // 5. Cargar debug info (solo en DEBUG)
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
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: "lock.fill")
                .foregroundStyle(AppTheme.Focus.textTertiary)
                .font(.title3)

            Text("game.input.disabled")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.Focus.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusCard(padding: AppTheme.CardPadding.standard)
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.bottom, AppTheme.Spacing.small)
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
                .foregroundStyle(AppTheme.Focus.textTertiary)

            Text("Ingresá tu primer intento para comenzar")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.Focus.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xLarge)
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
    let game: GameDetailSnapshot
    let onNewGame: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: AppTheme.Spacing.large) {
            Text("game.victory.title")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.appActionPrimary)

            // Métricas del juego
            VStack(spacing: AppTheme.Spacing.small) {
                MetricRow(
                    label: String(localized: "game.victory.secret"),
                    value: game.secret ?? "-----",
                    isMonospaced: true
                )
                MetricRow(label: String(localized: "game.victory.attempts"), value: "\(game.attempts.count)", isMonospaced: false)
            }
            .padding(AppTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(AppTheme.Focus.subSurface)
            )

            // CTA: Nueva partida
            Button(action: onNewGame) {
                Label("Nueva partida", systemImage: "plus.circle.fill")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appActionPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous)
                            .fill(Color.appActionPrimary.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous)
                            .strokeBorder(Color.appActionPrimary, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .focusCard(tint: .appActionPrimary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ganaste. Secreto: \(game.secret ?? "desconocido"). Intentos: \(game.attempts.count).")
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
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.Focus.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: isMonospaced ? .monospaced : .rounded))
                .foregroundStyle(AppTheme.Focus.textPrimary)
        }
    }
}

/// Card "Último intento": guess grande mono + barra segmentada Good/Fair/Poor + leyenda.
///
/// # Diseño
/// - El número destacado es el intento más reciente.
/// - La barra es proporcional (Good/Fair/Poor); el segmento Poor es neutro (gris),
///   como en el mock: verde / dorado / `rgba(255,255,255,.12)`.
private struct LastAttemptCard: View {
    let attempt: AttemptSnapshot

    private var good: Int { attempt.good }
    private var fair: Int { attempt.fair }
    private var poor: Int { max(0, GameConstants.secretLength - good - fair) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("daily.last_attempt")
                    .focusSectionLabel()
                Spacer()
                Text("game.last_attempt.hint")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textTertiary)
            }

            Text(attempt.guess)
                .focusMonoDigits(size: 40, weight: .bold, tracking: 6)
                .foregroundStyle(AppTheme.Focus.textPrimary)

            FeedbackBar(good: good, fair: fair, poor: poor)

            legend
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Último intento \(attempt.guess). \(good) Good, \(fair) Fair, \(poor) Poor.")
    }

    private var legend: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            legendItem(color: .appMarkGood, count: good, term: "Good")
            legendItem(color: .appMarkFair, count: fair, term: "Fair")
            legendItem(color: Color.white.opacity(0.30), count: poor, term: "Poor")
        }
    }

    private func legendItem(color: Color, count: Int, term: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text("\(count) \(term)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.Focus.textPrimary)
        }
    }
}

/// Barra segmentada proporcional Good / Fair / Poor.
private struct FeedbackBar: View {
    let good: Int
    let fair: Int
    let poor: Int

    private var total: CGFloat { CGFloat(max(1, good + fair + poor)) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.appMarkGood)
                    .frame(width: w * CGFloat(good) / total)
                Rectangle()
                    .fill(Color.appMarkFair)
                    .frame(width: w * CGFloat(fair) / total)
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: w * CGFloat(poor) / total)
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - CompactDeductionBoardView y CompactDigitCell eliminados
// Reemplazados por CollapsibleBoardHeader y AdaptiveDigitCell.
// - CollapsibleBoardHeader: header colapsable con grilla 2×5 adaptativa.
// - AdaptiveDigitCell: celda que interpola dimensiones según scroll offset.
// Ver CollapsibleBoardHeader.swift y AdaptiveDigitCell.swift.
