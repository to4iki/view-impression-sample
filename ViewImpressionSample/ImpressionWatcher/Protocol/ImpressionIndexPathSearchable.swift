import UIKit

enum ImpressionItemScrollableDirection {
    case vertical
    case horizontal
    case both
}

protocol ImpressionIndexPathSearchable {
    associatedtype Module: Hashable

    /// 観測するビューのスクロール方向
    var impressionItemScrollableDirection: ImpressionItemScrollableDirection { get }
    /// 計測対象を含むルートのビュー. 全体の範囲となる
    var impressionBaseCollectionView: CollectionViewForImpression { get }

    /// 見えているビューからモジュールと計測範囲のビューの組み合わせを取得する
    /// - Note: 計測対象の探索に伴う計算量は表示割合に比例するので、対象を絞り込むこと
    func impressionModuleViews(visibleViews: [UIView]) -> [Module: ModuleViewForImpression]
    /// モジュール単位で見えているビューが計測対象かどうか
    func impressionItem(visibleView: UIView, module: Module) -> Bool
}

extension ImpressionIndexPathSearchable {
    typealias ModuleIndexPaths = [Module: [IndexPath]]

    /// モジュール毎で指定された範囲からログ送信可となった対象 `IndexPath` の配列を探索する
    /// - Parameter visibleRate: 何%見えていたら送信対象とみなすか
    func searchImpressionIndexPaths(visibleRate: CGFloat) -> ModuleIndexPaths {
        let contentOffset = impressionBaseCollectionView.currentContentOffset
        var impGroupedIndexPaths: ModuleIndexPaths = [:]

        for (module, moduleView) in impressionModuleViews(visibleViews: impressionBaseCollectionView.currentVisibleViews) {
            let impItemIndexPathAndFrames = impressionItemIndexPathAndFrames(module: module, moduleView: moduleView)
            impGroupedIndexPaths[module] = impItemIndexPathAndFrames
                .filter { (_, frame) in hasImpressionItem(frame: frame, in: contentOffset, visibleRate: visibleRate) }
                .map { $0.key }
        }

        return impGroupedIndexPaths
    }
}

extension ImpressionIndexPathSearchable {
    /// 現在のスクロール位置に計測対象のフレームが含まれているか. `visibleRate` で何割見えているかを指定する
    private func hasImpressionItem(frame: CGRect, in contentOffset: CGPoint, visibleRate: CGFloat) -> Bool {
        func hasVertically() -> Bool {
            let visibleRangeVertical = (contentOffset.y...(contentOffset.y + impressionBaseCollectionView.currentBounds.height))
            let viewRange = frame.origin.y...(frame.origin.y + frame.height)
            let shrinkHeight = frame.height * (1.0 - visibleRate)
            let bounds = (visibleRangeVertical.lowerBound + shrinkHeight, visibleRangeVertical.upperBound - shrinkHeight)
            guard let impVisibleRange = ClosedRange(safe: bounds) else { return false }
            return impVisibleRange.overlaps(viewRange)
        }

        func hasHorizontally() -> Bool {
            let visibleRangeHorizontal = (contentOffset.x...(contentOffset.x + impressionBaseCollectionView.currentBounds.width))
            let viewRange = frame.origin.x...(frame.origin.x + frame.width)
            let shrinkWidth = frame.width * (1.0 - visibleRate)
            let bounds = (visibleRangeHorizontal.lowerBound + shrinkWidth, visibleRangeHorizontal.upperBound - shrinkWidth)
            guard let impVisibleRange = ClosedRange(safe: bounds) else { return false }
            return impVisibleRange.overlaps(viewRange)
        }

        switch impressionItemScrollableDirection {
        case .vertical:
            return hasVertically()
        case .horizontal:
            return hasHorizontally()
        case .both:
            return hasVertically() && hasHorizontally()
        }
    }

    /// モジュールの指定範囲から見えている計測対象の `IndexPath` とフレームの組み合わせを取得する
    private func impressionItemIndexPathAndFrames(module: Module, moduleView: ModuleViewForImpression) -> [IndexPath: CGRect] {
        return moduleView.currentVisibleViews
            .lazy
            .filter { self.impressionItem(visibleView: $0, module: module) }
            .reduce(into: [IndexPath: CGRect]()) { result, view in
                guard let indexPath = moduleView.indexPath(for: view) else { return }
                result[indexPath] = view.convert(view.bounds, to: impressionBaseCollectionView.asView)
        }
    }
}
