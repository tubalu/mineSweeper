import CoreGraphics

/// The four difficulty presets. `.nightmare` is the only one whose board
/// dimensions depend on the runtime screen size.
public enum Difficulty: Equatable, CaseIterable {
    case beginner, intermediate, expert, nightmare

    public func resolve(screenSize: CGSize) -> BoardDims {
        switch self {
        case .beginner: return BoardDims(rows: 9, cols: 9, mines: 10)
        case .intermediate: return BoardDims(rows: 16, cols: 16, mines: 40)
        case .expert: return BoardDims(rows: 16, cols: 30, mines: 99)
        case .nightmare:
            return nightmareDims(screenWidth: Double(screenSize.width),
                                 screenHeight: Double(screenSize.height))
        }
    }
}
