//
//  ModelContainerFactory.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation
import OSLog
import SwiftData

/// Factoría centralizada para construir el `ModelContainer`.
///
/// # Por qué existe
/// - DRY: un único lugar para la configuración del esquema y del store.
/// - Previews/Tests: permite crear contenedores `inMemory` sin tocar disco.
enum ModelContainerFactory {

    private static let logger = Logger(subsystem: "com.antolini.GuessIt", category: "Storage")

    /// Indica si se realizó una recuperación destructiva al inicio.
    /// La app puede leer este flag para mostrar una alerta al usuario.
    ///
    /// - Note: `nonisolated(unsafe)` es seguro aquí: solo se escribe en la rama de
    ///   recuperación (`!isInMemory`), que corre una única vez durante la creación
    ///   sincrónica del contenedor en el arranque real; nunca hay escritura concurrente.
    ///   Los contenedores in-memory (previews/tests) no tocan estos flags.
    nonisolated(unsafe) static private(set) var didRecoverFromCorruption = false

    /// URL del backup del store corrupto generado durante la última recuperación (si hubo).
    /// - Why: permite que una UI futura informe al usuario dónde quedó respaldada su data.
    /// - Note: ver la nota de `didRecoverFromCorruption` sobre `nonisolated(unsafe)`.
    nonisolated(unsafe) static private(set) var lastCorruptionBackupURL: URL?

    /// Construye un `ModelContainer` listo para usarse.
    /// - Parameter isInMemory: `true` para previews/tests (no escribe en disco), `false` para ejecución real.
    static func make(isInMemory: Bool) -> ModelContainer {
        // Listado final de modelos del juego.
        // Mantener este listado en un solo lugar evita inconsistencias y errores sutiles.
        let schema = Schema([
            Game.self,
            Attempt.self,
            DigitNote.self,
            GameStats.self,
            DailyChallenge.self
        ])

        // `isStoredInMemoryOnly` permite un store efímero (ideal para Previews) o persistente (ejecución real).
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isInMemory)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Si falla la creación del contenedor y no estamos en memoria,
            // respaldamos el store corrupto y recién entonces lo eliminamos y recreamos.
            if !isInMemory {
                logger.error("Error al crear ModelContainer: \(error.localizedDescription, privacy: .public)")

                let storeURL = configuration.url

                // 1) Backup NO destructivo antes de borrar nada.
                //    - Si el backup del archivo principal falla, NO borramos (evita pérdida silenciosa).
                do {
                    if let backup = try backupCorruptStore(at: storeURL) {
                        lastCorruptionBackupURL = backup
                        logger.warning("Store corrupto respaldado en \(backup.lastPathComponent, privacy: .public); recuperando…")
                    } else {
                        logger.warning("No había archivo de store para respaldar; recuperando…")
                    }
                } catch {
                    logger.error("Falló el backup del store corrupto: \(error.localizedDescription, privacy: .public). No se borra nada.")
                    fatalError("No se pudo respaldar el store corrupto antes de la recuperación; se aborta para no perder datos: \(error)")
                }

                // 2) Recuperación destructiva: borrar archivo principal + sidecars (ya respaldados).
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: storeURL)
                for sidecar in storeSidecarURLs(for: storeURL) {
                    try? fileManager.removeItem(at: sidecar)
                }

                didRecoverFromCorruption = true

                // 3) Intentar crear nuevamente.
                do {
                    logger.info("Base de datos recreada exitosamente tras recuperación.")
                    return try ModelContainer(for: schema, configurations: [configuration])
                } catch {
                    fatalError("No se pudo crear el ModelContainer después de limpiar: \(error)")
                }
            }

            // En un MVP es preferible fallar rápido antes que ejecutar con persistencia inconsistente.
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }

    // MARK: - Recuperación de store corrupto

    /// URLs de los sidecars WAL/SHM asociados a un store SQLite.
    ///
    /// # Por qué así
    /// - SQLite en modo WAL crea `<archivo>-wal` y `<archivo>-shm` (sufijo sobre el nombre
    ///   completo, incluida la extensión). Para `default.store` son `default.store-wal`/`-shm`.
    static func storeSidecarURLs(for storeURL: URL) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        return ["-wal", "-shm"].map { suffix in
            directory.appendingPathComponent(storeURL.lastPathComponent + suffix)
        }
    }

    /// Respalda (con timestamp) el store corrupto y sus sidecars antes de una recuperación destructiva.
    ///
    /// - Returns: URL del backup del archivo principal, o `nil` si el archivo principal no existe
    ///   (no hay nada útil que respaldar).
    /// - Throws: si el archivo principal existe pero **no se pudo respaldar**. El caller debe
    ///   abortar la recuperación en ese caso para no borrar datos silenciosamente.
    /// - Note: los sidecars se respaldan solo si existen (best-effort); su ausencia o un fallo
    ///   al copiarlos no aborta la operación.
    @discardableResult
    static func backupCorruptStore(at storeURL: URL) throws -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: storeURL.path) else { return nil }

        let stamp = corruptionTimestamp()
        let mainBackup = storeURL.appendingPathExtension("corrupt-\(stamp).bak")
        // Si esta copia falla, se propaga el error: el caller NO debe borrar.
        try fileManager.copyItem(at: storeURL, to: mainBackup)

        for sidecar in storeSidecarURLs(for: storeURL) where fileManager.fileExists(atPath: sidecar.path) {
            let sidecarBackup = sidecar.appendingPathExtension("corrupt-\(stamp).bak")
            try? fileManager.copyItem(at: sidecar, to: sidecarBackup)
        }

        return mainBackup
    }

    /// Timestamp seguro para nombres de archivo (sin `:`), en formato `yyyyMMdd-HHmmssSSS`.
    private static func corruptionTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmssSSS"
        return formatter.string(from: Date())
    }
}
