import CoreGraphics

enum ScrollDirection: Hashable {
    case left
    case down
    case up
    case right

    static func from(keyCode: CGKeyCode) -> ScrollDirection? {
        switch keyCode {
        case 4:  return .left   // H
        case 38: return .down   // J
        case 40: return .up     // K
        case 37: return .right  // L
        default: return nil
        }
    }

    var vector: (horizontal: Int32, vertical: Int32) {
        switch self {
        case .left:  return (1, 0)
        case .down:  return (0, -1)
        case .up:    return (0, 1)
        case .right: return (-1, 0)
        }
    }
}
enum ScrollSpeed: Int, CaseIterable {
    case slow = 5
    case normal = 10
    case fast = 18

    var title: String {
        switch self {
        case .slow: return "慢"
        case .normal: return "标准"
        case .fast: return "快"
        }
    }
}
