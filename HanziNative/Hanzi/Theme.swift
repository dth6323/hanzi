import SwiftUI

public struct AppColors {
    public static let bg = Color(hex: 0x12100F)
    public static let background = Color(hex: 0x12100F)
    public static let surface = Color(hex: 0x1D1A18)
    public static let surface2 = Color(hex: 0x282320)
    public static let surfaceLight = Color(hex: 0x282320)
    public static let primary = Color(hex: 0xE5483B)
    public static let vermilion = Color(hex: 0xE5483B)
    public static let gold = Color(hex: 0xE8B86B)
    public static let text = Color(hex: 0xF3ECE4)
    public static let textSecondary = Color(hex: 0xA79C91)
    public static let muted = Color(hex: 0xA79C91)
    public static let border = Color(hex: 0x282320)
    
    // Writing Canvas
    public static let paper = Color(hex: 0xF7F0E3)
    public static let ink = Color(hex: 0x221D1A)
    public static let outline = Color(hex: 0xDCCFBC)
    public static let userInk = Color(hex: 0x3A6EA5)
    public static let hint = Color(hex: 0x2E9E6A)
    public static let error = Color(hex: 0xD7392B)
    public static let grid = Color(hex: 0xD9B8A0)
    public static let gridStrong = Color(hex: 0xC0896B)
    
    public static func hskColor(_ level: Int) -> Color {
        switch level {
        case 1: return Color(hex: 0x4CAF84)
        case 2: return Color(hex: 0x3E9BD6)
        case 3: return Color(hex: 0x7A6FE0)
        case 4: return Color(hex: 0xD06BC4)
        case 5: return Color(hex: 0xE8914A)
        case 6: return Color(hex: 0xE5483B)
        default: return Color(hex: 0x9E2B25)
        }
    }
}

public typealias Theme = AppColors

public extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
