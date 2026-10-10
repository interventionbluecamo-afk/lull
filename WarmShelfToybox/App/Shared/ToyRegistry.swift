import SpriteKit

struct ToyDescriptor {
    let id: String
    let parentName: String
    let accentColor: UIColor
    let accessTier: LullAccessTier
    let isDemoReady: Bool
    let makeScene: (CGSize) -> BaseToyScene
}

enum ToyRegistry {
    static let bubblesID = "bubbles"
    static let clayBlocksID = "clayBlocks"
    static let feedThePeopleID = "feedThePeople"
    static let humID = "hum"
    static let softDropID = "softDrop"
    static let stackID = "stack"
    static let washID = "wash"
    static let bloomID = "bloom"
    static let mixUpID = "mixUp"
    static let glowboardID = "glowboard"
    static let sleepyDropBoxID = "sleepyDropBox"
    static let glowWindowID = "glowWindow"
    static let dropDotsID = "dropDots"
    static let doughID = "fold"  // key kept as "fold" so existing save states don't break
    static let currentID = "current"
    static let meadowID = "meadow"

    static let launchToyIDs = [
        bubblesID,
        feedThePeopleID,
        washID,
        sleepyDropBoxID,   // takes Glowboard's old free launch slot
        glowWindowID,      // flagship atmospheric room/window toy
        dropDotsID,        // chunky wooden gravity drop board
        mixUpID,
        humID,
        meadowID           // confirmed in the launch lineup (founder call, June 11)
    ]

    // Glowboard is parked off the child shelf — it read as a control panel rather than a toy
    // with one physical verb. Bloom, Dough (clay) and Current (water) are likewise parked. All
    // code is kept and revivable; nothing child-facing references them.
    static let archivedToyIDs = [
        stackID,
        clayBlocksID,
        softDropID,
        bloomID,
        glowboardID,
        doughID,
        currentID
    ]

    static let toys: [ToyDescriptor] = [
        ToyDescriptor(
            id: bubblesID,
            parentName: "Bubbles",
            accentColor: WarmShelfPalette.waterBlue,
            accessTier: .free,
            isDemoReady: true,
            makeScene: { size in BubbleScene(size: size) }
        ),
        ToyDescriptor(
            id: clayBlocksID,
            parentName: "Clay Blocks",
            accentColor: WarmShelfPalette.terracotta,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in ClayBlockScene(size: size) }
        ),
        ToyDescriptor(
            id: feedThePeopleID,
            parentName: "Feed",
            accentColor: WarmShelfPalette.petal,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in FeedScene(size: size) }
        ),
        ToyDescriptor(
            id: humID,
            parentName: "Hum",
            accentColor: WarmShelfPalette.terracotta,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in HumScene(size: size) }
        ),
        ToyDescriptor(
            id: softDropID,
            parentName: "Soft Drop",
            accentColor: WarmShelfPalette.sage,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in SoftDropScene(size: size) }
        ),
        ToyDescriptor(
            id: washID,
            parentName: "Little Wash",
            accentColor: WarmShelfPalette.waterBlue,
            accessTier: .free,
            isDemoReady: true,
            makeScene: { size in WashScene(size: size) }
        ),
        ToyDescriptor(
            id: stackID,
            parentName: "Stack",
            accentColor: WarmShelfPalette.terracotta,
            accessTier: .free,
            isDemoReady: true,
            makeScene: { size in StackScene(size: size) }
        ),
        ToyDescriptor(
            id: bloomID,
            parentName: "Bloom",
            accentColor: WarmShelfPalette.sage,
            accessTier: .free,
            isDemoReady: true,
            makeScene: { size in BloomScene(size: size) }
        ),
        ToyDescriptor(
            id: glowboardID,
            parentName: "Glowboard",
            accentColor: WarmShelfPalette.butter,
            accessTier: .free,
            isDemoReady: true,
            makeScene: { size in GlowboardScene(size: size) }
        ),
        ToyDescriptor(
            id: sleepyDropBoxID,
            parentName: "Sleepy Box",
            accentColor: WarmShelfPalette.sand,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in SleepyDropBoxScene(size: size) }
        ),
        ToyDescriptor(
            id: glowWindowID,
            parentName: "Window",
            accentColor: WarmShelfPalette.waterBlue,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in GlowWindowScene(size: size) }
        ),
        ToyDescriptor(
            id: dropDotsID,
            parentName: "Drop Dots",
            accentColor: WarmShelfPalette.rhubarb,
            accessTier: .free,
            isDemoReady: true,
            makeScene: { size in DropDotsScene(size: size) }
        ),
        ToyDescriptor(
            id: mixUpID,
            parentName: "Mix-Up",
            accentColor: WarmShelfPalette.lavender,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in MixUpScene(size: size) }
        ),
        ToyDescriptor(
            id: doughID,
            parentName: "Dough",
            accentColor: WarmShelfPalette.terracotta,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in DoughScene(size: size) }
        ),
        ToyDescriptor(
            id: currentID,
            parentName: "Current",
            accentColor: WarmShelfPalette.sage,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in CurrentScene(size: size) }
        ),
        ToyDescriptor(
            id: meadowID,
            parentName: "Meadow",
            accentColor: WarmShelfPalette.sage,
            accessTier: .fullToybox,
            isDemoReady: true,
            makeScene: { size in MeadowScene(size: size) }
        )
    ]

    static func toy(id: String) -> ToyDescriptor? {
        toys.first { $0.id == id }
    }

    /// Every object on the child's shelf must open when touched. The complete catalog and
    /// purchase story live only in the grown-up area. Toys a parent tucked away stay off the
    /// shelf (but at least one toy always remains — the shelf is never empty).
    static var childShelfToys: [ToyDescriptor] {
        let hidden = LullDemoState.shared.hiddenToyIDs
        let visible = launchToyIDs
            .compactMap(toy)
            .filter { $0.isDemoReady && !isToyLocked($0.id) && !hidden.contains($0.id) }
        if visible.isEmpty, let fallback = launchToyIDs.compactMap(toy).first(where: { !isToyLocked($0.id) }) {
            return [fallback]
        }
        return visible
    }

    /// A toy is unavailable to the child unless it's free or the grown-up has purchased it.
    static func isToyLocked(_ id: String) -> Bool {
        if LullDemoState.shared.hasFullToybox { return false }
        if toy(id: id)?.accessTier == .free { return false }
        return true
    }

    static var paidToyCountForParentPitch: Int {
        launchToyIDs
            .compactMap(toy)
            .filter { $0.accessTier == .fullToybox }
            .count
    }

}
