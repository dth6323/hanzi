import Foundation

public func hasCjk(_ text: String) -> Bool {
    return TextUtils.hasCjk(text)
}

public func cjkChars(_ text: String) -> [String] {
    return TextUtils.cjkChars(in: text)
}

public func removeDiacritics(_ text: String) -> String {
    return TextUtils.removeDiacritics(text)
}

public enum TextUtils {
    public static func hasCjk(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (v >= 0x4E00 && v <= 0x9FFF) ||
               (v >= 0x3400 && v <= 0x4DBF) ||
               (v >= 0x20000 && v <= 0x2A6DF) ||
               (v >= 0xF900 && v <= 0xFAFF) {
                return true
            }
        }
        return false
    }

    public static func cjkChars(in text: String) -> [String] {
        var result: [String] = []
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (v >= 0x4E00 && v <= 0x9FFF) ||
               (v >= 0x3400 && v <= 0x4DBF) ||
               (v >= 0x20000 && v <= 0x2A6DF) ||
               (v >= 0xF900 && v <= 0xFAFF) {
                result.append(String(scalar))
            }
        }
        return result
    }

    public static func removeDiacritics(_ text: String) -> String {
        return text.folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
    }
}
