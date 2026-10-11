#!/usr/bin/env python3
"""Run the production onboarding state logic with in-memory preferences."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "App/Shared/LullDemoState.swift").read_text()
state_source = source.split("@MainActor\nfinal class LullPurchaseManager", 1)[0]
assert "func completeOnboarding()" in state_source
state_source = state_source.replace("import StoreKit\n", "")

fixture = r'''
final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
    override func removeObject(forKey key: String) { values.removeValue(forKey: key) }
    override func object(forKey key: String) -> Any? { values[key] }
    override func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    override func integer(forKey key: String) -> Int { values[key] as? Int ?? 0 }
    override func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    override func string(forKey key: String) -> String? { values[key] as? String }
    override func array(forKey key: String) -> [Any]? { values[key] as? [Any] }
    override func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
}
final class LullPlayTimer {
    static let shared = LullPlayTimer()
    func settingsChanged() {}
}

func freshState() -> LullDemoState {
    LullDemoState(defaults: MemoryDefaults())
}

let day: TimeInterval = 86_400
let family = LullStoreProduct.familyYearly

let firstRun = freshState()
assert(!firstRun.hasCompletedOnboarding && !firstRun.hasFullToybox)
firstRun.completeOnboarding()
assert(firstRun.hasCompletedOnboarding && !firstRun.hasFullToybox)
assert(!firstRun.isInFreeWeek && !firstRun.parentAttentionWanted)
print("PASS: the welcome never opens toys by itself; the free week is the App Store's")

let legacyDefaults = MemoryDefaults()
legacyDefaults.set(Date().timeIntervalSinceReferenceDate, forKey: "lull.trialStartDate")
legacyDefaults.set(true, forKey: "lull.trialEndAcknowledged")
let legacy = LullDemoState(defaults: legacyDefaults)
assert(legacyDefaults.object(forKey: "lull.trialStartDate") == nil)
assert(legacyDefaults.object(forKey: "lull.trialEndAcknowledged") == nil)
assert(!legacy.hasFullToybox && !legacy.parentAttentionWanted)
print("PASS: the old on-device trial is cleared and grants nothing")

let week = freshState()
week.applyPlan(.init(productID: family, freeWeekEnds: Date().addingTimeInterval(6.5 * day), willRenew: true))
assert(week.hasFullToybox && week.hasSubscription && !week.hasKeepForever)
assert(week.isInFreeWeek && week.freeWeekDaysRemaining == 7 && week.planWillRenew == true)
assert(!week.parentAttentionWanted)
week.applyPlan(.init(productID: family, freeWeekEnds: Date().addingTimeInterval(0.5 * day), willRenew: false))
assert(week.freeWeekDaysRemaining == 1 && week.planWillRenew == false && week.parentAttentionWanted)
print("PASS: Lull Family's free week opens all toys; the last day shows the quiet dot")

let renewed = freshState()
renewed.applyPlan(.init(productID: family, freeWeekEnds: Date().addingTimeInterval(2 * day), willRenew: true))
renewed.applyPlan(.init(productID: family, freeWeekEnds: nil, willRenew: true))
assert(renewed.hasFullToybox && !renewed.isInFreeWeek && renewed.freeWeekDaysRemaining == 0)
assert(!renewed.parentAttentionWanted)
print("PASS: a paid renewal keeps the toybox open without a dot")

let replay = freshState()
replay.applyPlan(.init(productID: family, freeWeekEnds: nil, willRenew: true))
replay.hiddenToyIDs = ["hum"]
replay.windDownHour = 18
replay.isSoundEnabled = false
replay.resetOnboarding()
assert(!replay.hasCompletedOnboarding && replay.hasFullToybox)
replay.completeOnboarding()
assert(replay.hasFullToybox && replay.planProductID == family)
assert(replay.hiddenToyIDs == ["hum"] && replay.windDownHour == 18)
assert(!replay.isSoundEnabled)
print("PASS: replay preserves the plan and family preferences")

let lapsed = freshState()
lapsed.applyPlan(.init(productID: family, freeWeekEnds: Date().addingTimeInterval(day), willRenew: false))
lapsed.applyPlan(nil)
assert(!lapsed.hasFullToybox && !lapsed.hasSubscription && lapsed.freeWeekEndDate == nil)
assert(lapsed.hasUnseenPlanEnd && lapsed.parentAttentionWanted)
lapsed.acknowledgePlanState()
assert(!lapsed.parentAttentionWanted)
lapsed.applyPlan(nil)
assert(!lapsed.parentAttentionWanted)
print("PASS: a plan that ends returns the free shelf with one quiet dot until seen")

let forever = freshState()
forever.applyPlan(.init(productID: LullStoreProduct.lifetime, freeWeekEnds: Date().addingTimeInterval(day), willRenew: true))
assert(forever.hasFullToybox && forever.hasKeepForever && !forever.hasSubscription)
assert(forever.freeWeekEndDate == nil && forever.planWillRenew == nil && !forever.parentAttentionWanted)
forever.applyPlan(nil)
assert(!forever.hasFullToybox && !forever.parentAttentionWanted)
print("PASS: Keep Forever has no free week or renewal, and a refund leaves no plan dot")

let never = freshState()
never.applyPlan(nil)
assert(!never.hasFullToybox && !never.parentAttentionWanted)
print("PASS: a restore that finds nothing changes nothing")
'''

with tempfile.TemporaryDirectory(prefix="lull-onboarding-check-") as directory:
    check = Path(directory) / "OnboardingStateCheck.swift"
    check.write_text(state_source + fixture)
    subprocess.run([
        "/usr/bin/swift", "-module-cache-path", str(Path(directory) / "ModuleCache"),
        str(check)
    ], check=True)
