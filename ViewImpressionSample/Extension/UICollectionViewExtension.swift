import UIKit

extension UICollectionViewCell: Reusable {}

extension UICollectionView {
    func registerCell<T: Reusable>(type cell: T.Type) {
        register(cell.self, forCellWithReuseIdentifier: cell.identifier)
    }

    func dequeueReusableCell<T: Reusable>(type: T.Type, for indexPath: IndexPath) -> T {
        return dequeueReusableCell(withReuseIdentifier: type.identifier, for: indexPath) as! T
    }
}

// MARK: - Reusable

protocol Reusable: class {
    static var identifier: String { get }
}

extension Reusable {
    static var identifier: String {
        return String(describing: self)
    }
}
