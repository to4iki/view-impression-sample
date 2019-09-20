import RxRelay
import RxSwift
import UIKit

final class TopViewController: UIViewController {
    typealias Module = TopViewModel.Module

    private lazy var sections: [Section] = [
        SectionTitleSection(title: "Large"),
        LargeSection(),
        SectionTitleSection(title: "Medium(0)"),
        MediumSection(sectionIndex: 0),
        SectionTitleSection(title: "Medium(1)"),
        MediumSection(sectionIndex: 1),
        SectionTitleSection(title: "Small"),
        SmallSection()
    ]

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.registerCell(type: SectionTitleCell.self)
        collectionView.registerCell(type: Cell.self)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private lazy var collectionViewLayout: UICollectionViewLayout = {
        var sections = self.sections
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, environment) -> NSCollectionLayoutSection? in
            let sectionProvider = sections[sectionIndex]
            let section = sectionProvider.layoutSection()

            if sectionProvider is SectionWithInnerScrollView {
                section.visibleItemsInvalidationHandler = { (visibleItems, point, env) in
                    self.horizontalScrolling.accept(())
                }
            }
            return section
        }
        return layout
    }()

    private let refreshBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: nil)
        return barButtonItem
    }()

    private let impressionWatcher: ImpressionWatcher<Module> = {
        let configuration = ImpressionWatcherConfiguration(millisecondsTimerInterval: 500,
                                                           millisecondsPerSendLog: 1000,
                                                           itemVisibleRate: 0.5)
        let watcher = ImpressionWatcher<Module>(configuration: configuration)
        return watcher
    }()

    private lazy var impressionIndexPathSearcher: TopViewImpressionIndexPathSearcher =
        TopViewImpressionIndexPathSearcher(collectionView: self.collectionView)

    private let horizontalScrolling = PublishRelay<Void>()

    private let viewModel = TopViewModel()
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        layout: do {
            view.addSubview(collectionView)
            NSLayoutConstraint.activate([
                collectionView.topAnchor.constraint(equalTo: view.topAnchor),
                collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])

            navigationItem.setRightBarButton(refreshBarButtonItem, animated: false)
        }

        tracking: do {
            impressionWatcher.setup(
                searcher: impressionIndexPathSearcher,
                impressionTrigger: viewModel.output.impressionTrigger.asObservable(),
                sendModuleIndexPathsHandler: { [weak self] (moduleIndexPaths: [Module: [IndexPath]]) in
                    self?.viewModel.input.sendModuleIndexPaths.accept(moduleIndexPaths)
                }
            )
        }

        input: do {
            collectionView.rx.contentOffset
                .map { _ in }
                .bind(to: viewModel.input.verticalScrolling)
                .disposed(by: disposeBag)

            refreshBarButtonItem.rx.tap
                .observeOn(ConcurrentMainScheduler.instance)
                .subscribe(onNext: { [weak self] in
                    guard let me = self else { return }
                    let alertController = UIAlertController(title: nil,
                                                            message: "reset impression logs",
                                                            preferredStyle: .alert)
                    let okAlertAction = UIAlertAction(title: "ok", style: .default) { _ in
                        me.impressionWatcher.resetAllImpression()
                    }
                    alertController.addAction(okAlertAction)
                    alertController.addAction(UIAlertAction(title: "cancel", style: .cancel))
                    me.present(alertController, animated: true)
                })
                .disposed(by: disposeBag)

            horizontalScrolling.asObservable()
                .bind(to: viewModel.input.horizontalScrolling)
                .disposed(by: disposeBag)

            impressionWatcher.moduleSentCount
                .bind(to: viewModel.input.moduleSentCount)
                .disposed(by: disposeBag)
        }

        output: do {
            viewModel.output.allImpressionLogCompletion
                .observeOn(ConcurrentMainScheduler.instance)
                .subscribe(onNext: { [weak self] _ in
                    guard let me = self else { return }
                    let alertController = UIAlertController(title: nil,
                                                            message: "all item impression logs have been sent",
                                                            preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "ok", style: .default))
                    me.present(alertController, animated: true) {
                        me.impressionWatcher.dispose()
                    }
                })
                .disposed(by: disposeBag)
        }
    }
}

extension TopViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].numberOfItems
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return sections[indexPath.section].configureCell(collectionView: collectionView, indexPath: indexPath)
    }
}

extension TopViewController: UICollectionViewDelegate {}
