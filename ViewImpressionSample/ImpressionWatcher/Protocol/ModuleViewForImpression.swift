import UIKit

/// モジュール毎の計測要素を含むビュー
protocol ModuleViewForImpression: class {
    var currentVisibleViews: [UIView] { get }
    func indexPath(for view: UIView) -> IndexPath?
}

// MARK: UICollectionView

extension UICollectionView: ModuleViewForImpression {
    func indexPath(for view: UIView) -> IndexPath? {
        if let view = view as? UICollectionViewCell {
            return self.indexPath(for: view)
        }
        return nil
    }
}
