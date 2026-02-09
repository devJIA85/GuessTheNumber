import Foundation

/// Estado genérico de carga para operaciones asíncronas en la UI.
/// Permite modelar los estados: cargando, vacío, cargado con datos, o fallo.
///
/// # Nota sobre Equatable
/// Los casos `.failure` se comparan usando `String(reflecting:)` del error,
/// lo que permite comparar tipos de error sin requerir conformidad a Equatable.
/// Esto es una aproximación pragmática ya que `Error` no es `Equatable` por diseño.
enum LoadState<Value>: Equatable where Value: Equatable {
    case loading
    case empty
    case loaded(Value)
    case failure(Error)
    
    static func == (lhs: LoadState<Value>, rhs: LoadState<Value>) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.empty, .empty):
            return true
        case let (.loaded(lhsValue), .loaded(rhsValue)):
            return lhsValue == rhsValue
        case let (.failure(lhsError), .failure(rhsError)):
            // Comparamos errors usando su representación completa (tipo + contenido)
            // Nota: Error no es Equatable, así que usamos String(reflecting:) como proxy
            return String(reflecting: lhsError) == String(reflecting: rhsError)
        default:
            return false
        }
    }
    
    // MARK: - Computed Properties
    
    /// Indica si el estado actual es `.loading`.
    ///
    /// # Por qué útil
    /// - Facilita bindings para componentes UI como `DeferredProgressView`.
    /// - Más legible que comparar con switch o if-case en la UI.
    ///
    /// # Uso típico
    /// ```swift
    /// DeferredProgressView(isActive: loadState.isLoading, delay: .milliseconds(300))
    /// ```
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}
