import SwiftUI

struct Pt: Hashable {
    var x: Double
    var y: Double
    
    func dist(_ other: Pt) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

struct StrokeResult {
    let ok: Bool
    let reason: String?
    
    init(ok: Bool, reason: String? = nil) {
        self.ok = ok
        self.reason = reason
    }
}

func pathLength(_ pts: [Pt]) -> Double {
    guard pts.count >= 2 else { return 0 }
    var sum = 0.0
    for i in 1..<pts.count {
        sum += pts[i - 1].dist(pts[i])
    }
    return sum
}

func matchStroke(user: [Pt], median: [Pt]) -> StrokeResult {
    guard user.count >= 2, median.count >= 2 else {
        return StrokeResult(ok: false, reason: "Nét quá ngắn")
    }
    
    let uLen = pathLength(user)
    let mLen = pathLength(median)
    
    if uLen < 25 {
        return StrokeResult(ok: false, reason: "Nét quá ngắn")
    }
    
    // Check start and end distance
    let startDist = user.first!.dist(median.first!)
    let endDist = user.last!.dist(median.last!)
    
    // Check if reversed (wrong direction)
    let revStart = user.first!.dist(median.last!)
    let revEnd = user.last!.dist(median.first!)
    if (revStart + revEnd) < (startDist + endDist) && (revStart + revEnd) < 300 {
        return StrokeResult(ok: false, reason: "Viết ngược hướng nét")
    }
    
    let maxTolerance = max(180.0, mLen * 0.55)
    if startDist > maxTolerance {
        return StrokeResult(ok: false, reason: "Sai điểm bắt đầu")
    }
    
    if endDist > maxTolerance {
        return StrokeResult(ok: false, reason: "Sai điểm kết thúc")
    }
    
    // Check general length
    if uLen < mLen * 0.35 {
        return StrokeResult(ok: false, reason: "Nét chưa viết xong")
    }
    
    return StrokeResult(ok: true, reason: "Đúng nét")
}

func parseSvgPath(_ d: String) -> Path {
    var path = Path()
    let scanner = Scanner(string: d)
    scanner.charactersToBeSkipped = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ","))
    
    var currentPoint = CGPoint.zero
    
    while !scanner.isAtEnd {
        guard let command = scanner.scanCharacter() else { break }
        
        switch command {
        case "M":
            if let x = scanner.scanDouble(), let y = scanner.scanDouble() {
                currentPoint = CGPoint(x: x, y: y)
                path.move(to: currentPoint)
            }
        case "L":
            if let x = scanner.scanDouble(), let y = scanner.scanDouble() {
                currentPoint = CGPoint(x: x, y: y)
                path.addLine(to: currentPoint)
            }
        case "Q":
            if let x1 = scanner.scanDouble(), let y1 = scanner.scanDouble(),
               let x = scanner.scanDouble(), let y = scanner.scanDouble() {
                currentPoint = CGPoint(x: x, y: y)
                path.addQuadCurve(to: currentPoint, control: CGPoint(x: x1, y: y1))
            }
        case "C":
            if let x1 = scanner.scanDouble(), let y1 = scanner.scanDouble(),
               let x2 = scanner.scanDouble(), let y2 = scanner.scanDouble(),
               let x = scanner.scanDouble(), let y = scanner.scanDouble() {
                currentPoint = CGPoint(x: x, y: y)
                path.addCurve(to: currentPoint, control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
            }
        case "Z", "z":
            path.closeSubpath()
        default:
            break
        }
    }
    
    return path
}

enum StrokeMatcher {
    static func writingScore(mistakes: Int, totalStrokes: Int) -> Int {
        if mistakes == 0 { return 100 }
        let penalty = Double(mistakes) * 15.0 / Double(max(1, totalStrokes))
        return max(40, Int(100.0 - penalty * 10.0))
    }
}
