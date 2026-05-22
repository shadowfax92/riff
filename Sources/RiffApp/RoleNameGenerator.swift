import Foundation

/// Generates default role names like "Curious Otter" so the user gets a
/// readable placeholder instead of an empty field. Pairs an adjective with
/// a cute animal noun, both picked uniformly at random.
enum RoleNameGenerator {
    static func generate() -> String {
        let adjective = adjectives.randomElement() ?? "Curious"
        let animal = animals.randomElement() ?? "Otter"
        return "\(adjective) \(animal)"
    }

    private static let adjectives = [
        "Curious", "Quiet", "Brave", "Cheerful", "Sleepy", "Witty",
        "Cosmic", "Mellow", "Sunny", "Snowy", "Velvet", "Plucky",
        "Nimble", "Tiny", "Sage", "Bold", "Misty", "Lucky",
        "Speedy", "Patient", "Bright", "Gentle", "Sharp", "Steady",
    ]

    private static let animals = [
        "Otter", "Panda", "Fox", "Owl", "Lynx", "Quokka",
        "Hedgehog", "Wolf", "Badger", "Puffin", "Capybara", "Heron",
        "Mole", "Mongoose", "Wombat", "Lemur", "Sloth", "Koala",
        "Numbat", "Echidna", "Tapir", "Dingo", "Cheetah", "Pangolin",
    ]
}
