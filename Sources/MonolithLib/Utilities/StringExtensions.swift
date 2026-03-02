extension String {
    var capitalizingFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
