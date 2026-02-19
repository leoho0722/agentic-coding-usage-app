import Foundation

/// 從 API 錯誤回應 data 中擷取人類可讀的訊息。
///
/// 依序嘗試下列 JSON 格式：
/// - `{ "error": { "message": "..." } }` — OpenAI / Anthropic / Google
/// - `{ "error_description": "..." }` — OAuth 2.0
/// - `{ "message": "..." }` — GitHub
///
/// 皆不符時退回原始 UTF-8 字串。
///
/// - Parameter data: API 回應的原始資料。
/// - Returns: 擷取出的人類可讀錯誤訊息。
func extractErrorMessage(from data: Data) -> String {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        if let desc = json["error_description"] as? String {
            return desc
        }
        if let message = json["message"] as? String {
            return message
        }
    }
    return String(data: data, encoding: .utf8) ?? "Unknown error"
}
