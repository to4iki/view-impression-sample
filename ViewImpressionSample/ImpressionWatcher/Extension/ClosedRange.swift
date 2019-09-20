extension ClosedRange {
    init?(safe bounds: (lower: Bound, upper: Bound)) {
        guard bounds.upper >= bounds.lower else { return nil }
        self = bounds.lower...bounds.upper
    }
}
