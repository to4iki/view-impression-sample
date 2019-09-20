import RxRelay
import RxSwift
import UIKit

final class TopViewModel {
    let input = Input()
    let output = Output()

    private let disposeBag = DisposeBag()

    init() {
        Observable
            .merge(
                input.verticalScrolling.asObservable(),
                input.horizontalScrolling.asObservable()
            )
            .takeUntil(output.allImpressionLogCompletion.asObservable())
            .withLatestFrom(input.moduleSentCount) { $1 }
            .map(shouldSendTrackingEvent)
            .do(onNext: { [weak self] enabled in
                if !enabled {
                    self?.output.allImpressionLogCompletion.accept(())
                }
            })
            .filter { $0 }
            .map { _ in }
            .bind(to: output.impressionTrigger)
            .disposed(by: disposeBag)

        input.sendModuleIndexPaths.asObservable()
            .subscribe(onNext: {
                self.sendTrackingEvent(sendModuleIndexPaths: $0)
            })
            .disposed(by: disposeBag)
    }

    private func shouldSendTrackingEvent(moduleSentCellCount: [Module: Int]) -> Bool {
        let isSentAllItemInLarge = moduleSentCellCount[.large, default: 0] < Module.itemCount.large
        let isSentAllItemInMedium0 = moduleSentCellCount[.medium(sectionIndex: 0), default: 0] < Module.itemCount.medium
        let isSentAllItemInMedium1 = moduleSentCellCount[.medium(sectionIndex: 1), default: 0] < Module.itemCount.medium
        let isSentAllItemInSmall = moduleSentCellCount[.small, default: 0] < Module.itemCount.small
        return [isSentAllItemInLarge, isSentAllItemInMedium0, isSentAllItemInMedium1, isSentAllItemInSmall]
            .contains(true)
    }

    private func sendTrackingEvent(sendModuleIndexPaths: [Module: [IndexPath]]) {
        let sendModuleIndexPathPairs = sendModuleIndexPaths.flatMap { (module, sendIndexPaths) in
            sendIndexPaths.sorted().map { indexPath in (module, indexPath) }
        }

        for (module, indexPath) in sendModuleIndexPathPairs {
            switch module {
            case .large:
                print("large: \(indexPath.item)")
            case .medium(let sectionIndex):
                print("medium(\(sectionIndex)): \(indexPath.item)")
            case .small:
                print("small: \(indexPath.item)")
            }
        }
    }
}

extension TopViewModel {
    enum Module: Hashable {
        case large
        case medium(sectionIndex: Int)
        case small

        static let itemCount = (large: 3, medium: 9, small: 10)
    }
}

extension TopViewModel {
    struct Input {
        let verticalScrolling = PublishRelay<Void>()
        let horizontalScrolling = PublishRelay<Void>()
        let moduleSentCount = PublishRelay<[Module: Int]>()
        let sendModuleIndexPaths = PublishRelay<[Module: [IndexPath]]>()
    }

    struct Output {
        let impressionTrigger = PublishRelay<Void>()
        let allImpressionLogCompletion = PublishRelay<Void>()
    }
}
