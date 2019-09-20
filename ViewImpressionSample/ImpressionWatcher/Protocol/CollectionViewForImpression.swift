import UIKit

/// 計測対象のモジュールを内包するルートの `UICollectionView`
protocol CollectionViewForImpression: class {
    var asView: UIView { get }
    var currentVisibleViews: [UIView] { get }
    var currentContentOffset: CGPoint { get }
}

extension CollectionViewForImpression {
    var currentBounds: CGRect {
        return asView.bounds
    }
}

// MARK: UICollectionView

extension UICollectionView: CollectionViewForImpression {
    var asView: UIView {
        return self
    }

    var currentVisibleViews: [UIView] {
        return self.visibleCells
    }

    var currentContentOffset: CGPoint {
        return contentOffset
    }
}

// MARK: - DefaultCollectionViewForImpression

typealias DefaultCollectionViewForImpression = (CollectionViewForImpression & ModuleViewForImpression)
