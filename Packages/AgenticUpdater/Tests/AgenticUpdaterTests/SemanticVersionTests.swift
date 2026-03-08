import Foundation
import Testing

@testable import AgenticUpdater

@Suite("SemanticVersion")
struct SemanticVersionTests {

    // MARK: - Parsing

    /// 驗證標準三段式版本號能正確解析為 major、minor、patch
    @Test
    func parse_standard() {
        let v = SemanticVersion("1.8.0")
        #expect(v != nil)
        #expect(v?.major == 1)
        #expect(v?.minor == 8)
        #expect(v?.patch == 0)
    }

    /// 驗證帶有小寫 v 前綴的版本字串能正確解析
    @Test
    func parse_withLowercaseV() {
        let v = SemanticVersion("v1.8.0")
        #expect(v != nil)
        #expect(v?.major == 1)
        #expect(v?.minor == 8)
        #expect(v?.patch == 0)
    }

    /// 驗證帶有大寫 V 前綴的版本字串能正確解析
    @Test
    func parse_withUppercaseV() {
        let v = SemanticVersion("V2.0.1")
        #expect(v != nil)
        #expect(v?.major == 2)
        #expect(v?.minor == 0)
        #expect(v?.patch == 1)
    }

    /// 驗證僅有兩段的版本字串回傳 nil
    @Test
    func parse_twoComponents_returnsNil() {
        #expect(SemanticVersion("1.8") == nil)
    }

    /// 驗證空字串回傳 nil
    @Test
    func parse_empty_returnsNil() {
        #expect(SemanticVersion("") == nil)
    }

    /// 驗證非數字字串回傳 nil
    @Test
    func parse_nonNumeric_returnsNil() {
        #expect(SemanticVersion("a.b.c") == nil)
    }

    /// 驗證僅有單一數字的字串回傳 nil
    @Test
    func parse_singleNumber_returnsNil() {
        #expect(SemanticVersion("1") == nil)
    }

    // MARK: - Comparable

    /// 驗證主版本號不同時的大小比較正確
    @Test
    func comparable_majorDifference() {
        let v1 = SemanticVersion("1.0.0")!
        let v2 = SemanticVersion("2.0.0")!
        #expect(v1 < v2)
        #expect(!(v2 < v1))
    }

    /// 驗證次版本號不同時的大小比較正確
    @Test
    func comparable_minorDifference() {
        let v1 = SemanticVersion("1.0.0")!
        let v2 = SemanticVersion("1.1.0")!
        #expect(v1 < v2)
    }

    /// 驗證修訂版本號不同時的大小比較正確
    @Test
    func comparable_patchDifference() {
        let v1 = SemanticVersion("1.0.0")!
        let v2 = SemanticVersion("1.0.1")!
        #expect(v1 < v2)
    }

    /// 驗證版本號完全相同時判定為相等且不分大小
    @Test
    func comparable_equal() {
        let v1 = SemanticVersion("1.8.0")!
        let v2 = SemanticVersion("1.8.0")!
        #expect(v1 == v2)
        #expect(!(v1 < v2))
        #expect(!(v2 < v1))
    }

    // MARK: - description

    /// 驗證 description 不含 v 前綴
    @Test
    func description_noPrefix() {
        let v = SemanticVersion("v1.8.0")!
        #expect(v.description == "1.8.0")
    }

    /// 驗證 description 格式為 major.minor.patch
    @Test
    func description_format() {
        let v = SemanticVersion("10.20.30")!
        #expect(v.description == "10.20.30")
    }
}
