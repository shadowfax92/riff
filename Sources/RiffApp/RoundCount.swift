enum RoundCount {
    static func normalized(_ value: Int) -> Int {
        max(1, value)
    }
}
