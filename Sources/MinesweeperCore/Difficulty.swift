import CoreGraphics

/// The four presets plus a user-entered custom size. `.nightmare` is the
/// only preset whose board dimensions depend on the runtime screen size;
/// `.custom` carries its own explicit `BoardDims` and also ignores
/// `screenSize`, same as the three static presets.
public enum Difficulty: Equatable {
    case beginner, intermediate, expert, nightmare
    case custom(BoardDims)

    public func resolve(screenSize: CGSize) -> BoardDims {
        switch self {
        case .beginner: return BoardDims(rows: 9, cols: 9, mines: 10)
        case .intermediate: return BoardDims(rows: 16, cols: 16, mines: 40)
        case .expert: return BoardDims(rows: 16, cols: 30, mines: 99)
        case .nightmare:
            return nightmareDims(screenWidth: Double(screenSize.width),
                                 screenHeight: Double(screenSize.height))
        case .custom(let dims):
            return dims
        }
    }
}
