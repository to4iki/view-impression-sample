import UIKit

struct MediumSection: SectionWithInnerScrollView {
    let numberOfItems = TopViewModel.Module.itemCount.medium
    let sectionIndex: Int

    func layoutSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.92),
                                               heightDimension: .fractionalHeight(0.3))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitem: item, count: 3)

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous

        return section
    }

    func configureCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: Cell.self, for: indexPath)
        cell.title = "\(sectionIndex):\(indexPath.item)"
        cell.backgroundColor = .systemYellow
        cell.moduleForImpression = .medium(sectionIndex: sectionIndex)
        return cell
    }
}
