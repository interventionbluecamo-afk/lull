import SpriteKit

/// A signature surface decoration that makes each biome instantly recognizable.
enum BiomeProp {
    case daisies      // meadow
    case palm         // desert island
    case pine         // snowy
    case fireflies    // night forest
}

/// A whole-world theme for Bloom. A seed picks one, then it recolors the soil, grass,
/// sky, the flowers you grow, the critters that live there, and adds a signature prop —
/// so every garden feels like a different place to discover.
struct BloomBiome {
    let id: String
    let soil: UIColor
    let deepSoil: UIColor
    let grass: UIColor
    let skyWash: UIColor
    let skyWashAlpha: CGFloat
    let flowerColors: [UIColor]
    let critterKinds: [GardenCritterKind]
    let critterTint: UIColor?
    let prop: BiomeProp

    static let meadow = BloomBiome(
        id: "meadow",
        soil: UIColor(hex: 0x6E4B34), deepSoil: UIColor(hex: 0x533620),
        grass: WarmShelfPalette.sage,
        skyWash: WarmShelfPalette.sage, skyWashAlpha: 0.05,
        flowerColors: [WarmShelfPalette.petal, WarmShelfPalette.butter, WarmShelfPalette.lavender,
                       WarmShelfPalette.rhubarb, WarmShelfPalette.waterBlue, WarmShelfPalette.terracotta],
        critterKinds: [.mouse, .bear, .bird], critterTint: nil,
        prop: .daisies
    )

    static let desertIsland = BloomBiome(
        id: "desertIsland",
        soil: UIColor(hex: 0xCFA968), deepSoil: UIColor(hex: 0xB08A4C),
        grass: UIColor(hex: 0xB7A05C),
        skyWash: WarmShelfPalette.terracotta, skyWashAlpha: 0.10,
        flowerColors: [WarmShelfPalette.terracotta, WarmShelfPalette.butter, WarmShelfPalette.rhubarb, WarmShelfPalette.petal],
        critterKinds: [.bird, .mouse], critterTint: UIColor(hex: 0xD9B97A),
        prop: .palm
    )

    // Was a cold snow biome — re-skinned warm as a soft blossom meadow so Lull never
    // leaves its warm-cream world.
    static let snowy = BloomBiome(
        id: "snowy",
        soil: UIColor(hex: 0xCDB48A), deepSoil: UIColor(hex: 0xB1976B),
        grass: WarmShelfPalette.sage,
        skyWash: WarmShelfPalette.petal, skyWashAlpha: 0.06,
        flowerColors: [WarmShelfPalette.petal, WarmShelfPalette.butter, WarmShelfPalette.lavender, WarmShelfPalette.paperHighlight],
        critterKinds: [.bear, .bird], critterTint: UIColor(hex: 0xE8D6B0),
        prop: .pine
    )

    // Was a dark night forest — re-skinned as a warm golden-dusk grove (fireflies kept).
    static let nightForest = BloomBiome(
        id: "nightForest",
        soil: UIColor(hex: 0x6E4B34), deepSoil: UIColor(hex: 0x533620),
        grass: UIColor(hex: 0x6A8B66),
        skyWash: UIColor(hex: 0xE9A85C), skyWashAlpha: 0.12,
        flowerColors: [WarmShelfPalette.butter, WarmShelfPalette.petal, WarmShelfPalette.terracotta, WarmShelfPalette.rhubarb],
        critterKinds: [.mouse, .bear], critterTint: UIColor(hex: 0xD9B98A),
        prop: .fireflies
    )

    static let all: [BloomBiome] = [meadow, desertIsland, snowy, nightForest]

    static func pick(using rng: inout SeededGenerator) -> BloomBiome {
        all.randomElement(using: &rng) ?? meadow
    }
}
