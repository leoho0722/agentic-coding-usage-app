import Foundation

/// 提供 `FileManager` 的額外輔助功能。
extension FileManager {
    
    /// 取得目前使用者的真實家目錄。
    ///
    /// 在 App Sandbox 中，`homeDirectoryForCurrentUser` 回傳容器路徑，
    /// 需使用 `getpwuid` 取得真實家目錄，搭配 absolute-path entitlement 存取。
    var realHomeDirectory: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir))
        }
        return homeDirectoryForCurrentUser
    }
}
