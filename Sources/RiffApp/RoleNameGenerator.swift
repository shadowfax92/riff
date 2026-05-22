import Foundation

struct AnimalIdentity: Equatable {
    let name: String
    let emoji: String
}

/// Picks a random `AnimalIdentity` so each role gets a single-word default
/// name and a matching emoji that the avatar can render in place of
/// letter initials.
enum RoleNameGenerator {
    static func generate() -> AnimalIdentity {
        animals.randomElement() ?? AnimalIdentity(name: "Fox", emoji: "🦊")
    }

    static let animals: [AnimalIdentity] = [
        AnimalIdentity(name: "Fox", emoji: "🦊"),
        AnimalIdentity(name: "Wolf", emoji: "🐺"),
        AnimalIdentity(name: "Bear", emoji: "🐻"),
        AnimalIdentity(name: "Panda", emoji: "🐼"),
        AnimalIdentity(name: "Koala", emoji: "🐨"),
        AnimalIdentity(name: "Tiger", emoji: "🐯"),
        AnimalIdentity(name: "Lion", emoji: "🦁"),
        AnimalIdentity(name: "Cat", emoji: "🐱"),
        AnimalIdentity(name: "Dog", emoji: "🐶"),
        AnimalIdentity(name: "Mouse", emoji: "🐭"),
        AnimalIdentity(name: "Hamster", emoji: "🐹"),
        AnimalIdentity(name: "Rabbit", emoji: "🐰"),
        AnimalIdentity(name: "Cow", emoji: "🐮"),
        AnimalIdentity(name: "Pig", emoji: "🐷"),
        AnimalIdentity(name: "Frog", emoji: "🐸"),
        AnimalIdentity(name: "Monkey", emoji: "🐵"),
        AnimalIdentity(name: "Elephant", emoji: "🐘"),
        AnimalIdentity(name: "Giraffe", emoji: "🦒"),
        AnimalIdentity(name: "Hippo", emoji: "🦛"),
        AnimalIdentity(name: "Rhino", emoji: "🦏"),
        AnimalIdentity(name: "Zebra", emoji: "🦓"),
        AnimalIdentity(name: "Otter", emoji: "🦦"),
        AnimalIdentity(name: "Badger", emoji: "🦡"),
        AnimalIdentity(name: "Sloth", emoji: "🦥"),
        AnimalIdentity(name: "Hedgehog", emoji: "🦔"),
        AnimalIdentity(name: "Bat", emoji: "🦇"),
        AnimalIdentity(name: "Skunk", emoji: "🦨"),
        AnimalIdentity(name: "Owl", emoji: "🦉"),
        AnimalIdentity(name: "Eagle", emoji: "🦅"),
        AnimalIdentity(name: "Duck", emoji: "🦆"),
        AnimalIdentity(name: "Swan", emoji: "🦢"),
        AnimalIdentity(name: "Penguin", emoji: "🐧"),
        AnimalIdentity(name: "Parrot", emoji: "🦜"),
        AnimalIdentity(name: "Peacock", emoji: "🦚"),
        AnimalIdentity(name: "Flamingo", emoji: "🦩"),
        AnimalIdentity(name: "Whale", emoji: "🐳"),
        AnimalIdentity(name: "Dolphin", emoji: "🐬"),
        AnimalIdentity(name: "Shark", emoji: "🦈"),
        AnimalIdentity(name: "Octopus", emoji: "🐙"),
        AnimalIdentity(name: "Crab", emoji: "🦀"),
        AnimalIdentity(name: "Turtle", emoji: "🐢"),
        AnimalIdentity(name: "Snake", emoji: "🐍"),
        AnimalIdentity(name: "Lizard", emoji: "🦎"),
        AnimalIdentity(name: "Kangaroo", emoji: "🦘"),
        AnimalIdentity(name: "Beaver", emoji: "🦫"),
        AnimalIdentity(name: "Squirrel", emoji: "🐿️"),
        AnimalIdentity(name: "Butterfly", emoji: "🦋"),
        AnimalIdentity(name: "Bee", emoji: "🐝"),
        AnimalIdentity(name: "Ladybug", emoji: "🐞"),
        AnimalIdentity(name: "Llama", emoji: "🦙"),
    ]
}
