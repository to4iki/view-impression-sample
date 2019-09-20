import RxCocoa
import RxSwift

/// InView Impression ログ送信のタイミングの監視を行う
final class ImpressionWatcher<Module: Hashable> {
    /// モジュール毎のImpログ送信済みの要素数
    let moduleSentCount: Observable<[Module: Int]>

    /// - TODO: use `BehaviorRelay`
    private let _moduleSentCount = Variable<[Module: Int]>([:])

    private let configuration: ImpressionWatcherConfiguration

    /// Impログを監視しているタイマーの終了時間を引き延ばすことの通知
    private let _updateTimerDuration = PublishRelay<Void>()

    /// Impログの送信状態の更新
    private let _didUpdateIsSent = PublishRelay<Void>()

    /// モジュール単位での送信済みかどうかの状態
    /// - TODO: use `BehaviorRelay`
    private let _moduleImpressionStates = Variable<[Module: [IndexPath: ImpressionState]]>([:])

    private let disposeBag = DisposeBag()
    private var reusableDisposeBag: DisposeBag?

     init(configuration: ImpressionWatcherConfiguration) {
        self.configuration = configuration

        moduleSentCount = _moduleSentCount.asObservable()

        _didUpdateIsSent.asObservable()
            .withLatestFrom(_moduleImpressionStates.asObservable()) { $1 }
            .subscribe(onNext: { [weak self] moduleImpressionStates in
                guard let me = self else { return }
                moduleImpressionStates.forEach { module, value in
                    let sentCount = value.filter { $0.value.isSent }.count
                    me._moduleSentCount.value[module] = sentCount
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Internal

extension ImpressionWatcher {
    /// モジュール毎のログ送信対象 `IndexPath` の配列
    typealias ModuleIndexPaths = [Module: [IndexPath]]
    
    /// Impログの監視設定
    ///
    /// - parameters:
    ///   - searcher: ログ送信対象の `IndexPath` の探索
    ///   - impressionTrigger: 送信対象か検証開始するためのトリガー
    ///   - sendModuleIndexPathsHandler: 送信対象のログのハンドラ
    ///   - ex. 画面内に入ってから1秒未満で画面外へ外れた後、再び50%以上画面内に入った場合タイマーのカウントは0秒から始める
    func setup<Searchable: ImpressionIndexPathSearchable>(
        searcher: Searchable,
        impressionTrigger: Observable<Void>,
        sendModuleIndexPathsHandler: @escaping (ModuleIndexPaths) -> Void) where Searchable.Module == Module {

        // 何度呼ばれても大丈夫なように `reusableDisposeBag` を利用する
        let disposeBag = DisposeBag()
        reusableDisposeBag = disposeBag

        let shareImpTrigger = impressionTrigger.share()

        shareImpTrigger
            // `flatMapFirst` によって、一度生成した内部タイマーを、不要になるまで使い続ける
            .flatMapFirst { [weak self] _ -> Observable<ModuleIndexPaths> in
                guard let me = self else { return .empty() }

                return Observable<Int>.interval(.milliseconds(me.configuration.millisecondsTimerInterval),
                                                scheduler: ConcurrentMainScheduler.instance)
                    .takeUntil(
                        // 内部タイマーの寿命を設定
                        // - `startWith(())` + `debounce` + `takeUntil` でタイマーの初期寿命を設定
                        // - `_updateTimerDuration` の発火でタイマー寿命を延長させる
                        me._updateTimerDuration.asObservable()
                            .startWith(())
                            // - Attention: 確実にImpログチェックをし切るために送信判定時間を0.05秒伸ばす
                            .debounce(.milliseconds(me.configuration.millisecondsTimerInterval + 50),
                                      scheduler: ConcurrentMainScheduler.instance)
                    )
                    .flatMap { [weak self] _ -> Observable<ModuleIndexPaths> in
                        guard let me = self else { return .empty() }
                        // 見えている `ModuleIndexPaths`
                        let moduleIndexPaths = searcher.searchImpressionIndexPaths(visibleRate: me.configuration.itemVisibleRate)
                        // 見えている要素のうち、`1000ms` 経過しているログ送信対象の `ModuleIndexPaths` を取得する
                        let sendModuleIndexPaths = me.updateImpressionStateAndSendLogIfNeeded(
                            currentMilliseconds: Int(Date().timeIntervalSince1970 * 1000),
                            moduleIndexPaths: moduleIndexPaths
                        )
                        return .just(sendModuleIndexPaths)
                }
            }
            .subscribe(onNext: { sendModuleIndexPaths in
                if !sendModuleIndexPaths.isEmpty {
                    sendModuleIndexPathsHandler(sendModuleIndexPaths)
                }
            })
            .disposed(by: disposeBag)
    }

     func resetAllImpression() {
        _moduleImpressionStates.value = [:]
        _moduleSentCount.value = [:]
    }

    func dispose() {
        self.reusableDisposeBag = nil
    }
}

// MARK: - Private

extension ImpressionWatcher {
    /// 各 `IndexPath` 毎の送信状態の更新
    ///
    /// - parameters:
    ///   - currentMilliseconds: タイマーから毎回送られてくる現在時刻(milliseconds)
    ///   - moduleIndexPaths: インプレッション領域に含まれている `ModuleIndexPaths`
    ///
    /// - Returns: 任意時間見られた `ModuleIndexPaths`
    private func updateImpressionStateAndSendLogIfNeeded(currentMilliseconds: Int,
                                                         moduleIndexPaths: ModuleIndexPaths) -> ModuleIndexPaths {
        var sendModuleIndexPaths: ModuleIndexPaths = [:]
        var shouldUpdateTimerDuration = false

        moduleIndexPaths.forEach { module, indexPaths in
            var sendIndexPaths: [IndexPath] = []
            var newImpressionStates: [IndexPath: ImpressionState] = [:]

            indexPaths.forEach { indexPath in
                if let impressionStates = _moduleImpressionStates.value[module],
                    let impressionState = impressionStates[indexPath] {
                    // 送っていなければ、Imp時間を確認してImpログを送る `indexPath` を `sendIndexPaths` に格納する
                    if !impressionState.isSent {
                        if impressionState.time <= (currentMilliseconds - configuration.millisecondsPerSendLog) {
                            impressionState.isSent = true
                            sendIndexPaths.append(indexPath)
                        } else {
                            // まだ送っていないため、タイマーの終了時間を引き延ばす
                            shouldUpdateTimerDuration = true
                        }
                    }
                } else {
                    newImpressionStates[indexPath] = ImpressionState(time: currentMilliseconds)
                    // 初めて登録した `indexPath` の場合、タイマーの終了時間を引き延ばす
                    shouldUpdateTimerDuration = true
                }
            }

            if _moduleImpressionStates.value[module] != nil {
                newImpressionStates.forEach { key, value in
                    _moduleImpressionStates.value[module]?[key] = value
                }
            } else {
                _moduleImpressionStates.value[module] = newImpressionStates
            }
            if !sendIndexPaths.isEmpty {
                _didUpdateIsSent.accept(())
                sendModuleIndexPaths[module] = sendIndexPaths
            }
        }

        // タイマーの終了時間を引き延ばす必要がある場合は発火させる
        if shouldUpdateTimerDuration {
            _updateTimerDuration.accept(())
        }

        moduleIndexPaths.forEach { module, indexPaths in
            let impressionStateIndexPaths = _moduleImpressionStates.value[module]?.map { $0.key }

            if let impressionStateIndexPaths = impressionStateIndexPaths {
                let removeIndexPaths = Set<IndexPath>(impressionStateIndexPaths).subtracting(indexPaths)
                removeIndexPaths.forEach { indexPath in

                    if let impressionStates = _moduleImpressionStates.value[module],
                        let impressionState = impressionStates[indexPath],
                        impressionState.isSent {
                        return
                    }
                    _moduleImpressionStates.value[module]?.removeValue(forKey: indexPath)
                }
            }
        }
        return sendModuleIndexPaths
    }
}
