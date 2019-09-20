import UIKit

final class TopViewImpressionIndexPathSearcher {
    private let collectionView: DefaultCollectionViewForImpression

    init(collectionView: DefaultCollectionViewForImpression) {
        self.collectionView = collectionView
    }
}

// MARK: - ImpressionIndexPathSearchable

extension TopViewImpressionIndexPathSearcher: ImpressionIndexPathSearchable {
    typealias Module = TopViewModel.Module

    var impressionItemScrollableDirection: ImpressionItemScrollableDirection {
        return .both
    }

    var impressionBaseCollectionView: CollectionViewForImpression {
        return collectionView
    }

    func impressionModuleViews(visibleViews: [UIView]) -> [TopViewModel.Module : ModuleViewForImpression] {
        var moduleViews: [Module: ModuleViewForImpression] = [:]
        for visibleView in visibleViews {
            guard let _visibleView = visibleView as? CellForImpression else { continue }
            guard let module = _visibleView.moduleForImpression else { continue }
            moduleViews[module] = collectionView
        }
        return moduleViews
    }

    func impressionItem(visibleView: UIView, module: TopViewModel.Module) -> Bool {
        guard let cellForImpression = visibleView as? CellForImpression else { return false }
        guard let moduleForImpression = cellForImpression.moduleForImpression else { return false }
        return moduleForImpression == module
    }
}
