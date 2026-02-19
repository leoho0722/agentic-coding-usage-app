import Foundation
import SQLite3

// MARK: - SQLite 讀取器

/// 最小化的 SQLite C API 封裝，僅提供唯讀單值查詢功能。
///
/// 用於從 Antigravity 的 VSCode 狀態資料庫讀取憑證資料。
/// 在 App Sandbox 環境下，SQLite C API 不支援沙盒路徑轉譯，
/// 因此提供透過 FileManager 複製到快取目錄後再讀取的備援機制。
public enum SQLiteReader {

    /// 從指定 SQLite 資料庫讀取 `ItemTable` 中對應 key 的 value。
    ///
    /// 先嘗試直接以 SQLite C API 開啟；若失敗（例如受 App Sandbox 限制），
    /// 會透過 `FileManager` 將資料庫複製到快取目錄後再讀取。
    ///
    /// - Parameters:
    ///   - dbPath: SQLite 資料庫檔案的完整路徑。
    ///   - key: 要查詢的鍵名。
    /// - Returns: 對應的字串值，找不到或失敗時回傳 `nil`。
    public static func readValue(from dbPath: String, forKey key: String) -> String? {
        // 1. 直接嘗試以 SQLite C API 開啟
        if let result = directQuery(dbPath: dbPath, forKey: key) {
            return result
        }

        // 2. 若直接開啟失敗，透過 FileManager 複製到快取目錄再讀取
        //    （FileManager 支援 App Sandbox 路徑轉譯，SQLite C API 不支援）
        return queryViaCopy(from: dbPath, forKey: key)
    }
}

// MARK: - 私有輔助

private extension SQLiteReader {

    /// 直接以 SQLite C API 開啟資料庫並查詢。
    static func directQuery(dbPath: String, forKey key: String) -> String? {
        var db: OpaquePointer?

        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        return executeQuery(db: db!, forKey: key)
    }

    /// 透過 FileManager 將資料庫複製到快取目錄後，以 SQLite C API 查詢。
    ///
    /// `FileManager.contents(atPath:)` 支援 App Sandbox 的 temporary-exception
    /// 路徑轉譯機制，可存取 entitlements 中宣告的家目錄相對路徑。
    static func queryViaCopy(from originalPath: String, forKey key: String) -> String? {
        let fileManager = FileManager.default

        // 使用 FileManager 讀取原始檔案（支援 App Sandbox 路徑轉譯）
        guard let dbData = fileManager.contents(atPath: originalPath) else {
            return nil
        }

        // 寫入快取目錄（App 容器內，SQLite C API 可直接存取）
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let tempFileName = UUID().uuidString + ".sqlite"
        let tempURL = cacheDir.appendingPathComponent(tempFileName)

        guard fileManager.createFile(atPath: tempURL.path, contents: dbData) else {
            return nil
        }
        defer { try? fileManager.removeItem(at: tempURL) }

        return directQuery(dbPath: tempURL.path, forKey: key)
    }

    /// 對已開啟的 SQLite 資料庫執行查詢。
    static func executeQuery(db: OpaquePointer, forKey key: String) -> String? {
        var stmt: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1"

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        guard let cString = sqlite3_column_text(stmt, 0) else {
            return nil
        }

        return String(cString: cString)
    }
}
