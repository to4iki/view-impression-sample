import Foundation

final class ImpressionState {
    let time: Int
    var isSent: Bool = false

    init(time: Int) {
        self.time = time
    }
}
