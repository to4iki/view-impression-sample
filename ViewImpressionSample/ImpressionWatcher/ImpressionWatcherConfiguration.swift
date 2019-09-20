import UIKit

struct ImpressionWatcherConfiguration {
    /// 検証の間隔(milliseconds)
    /// - Note: `500` 500ms毎にタイマーを実行する
    let millisecondsTimerInterval: Int

    /// ログ送信対象とみなすまでの時間(milliseconds)
    /// - Note: `1000` 1000ms経過後に送信対象とする
    let millisecondsPerSendLog: Int

    /// 要素の表示割合
    /// - Note: `0.5` 50%見えていれば送信対象とする
    let itemVisibleRate: CGFloat
}
