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

let firstRun = freshState()
assert(!firstRun.hasTrialStarted && !firstRun.hasCompletedOnboarding)
firstRun.completeOnboarding()
assert(firstRun.hasCompletedOnboarding && firstRun.isTrialActive)
assert(!firstRun.hasPurchasedFullToybox && firstRun.trialDaysRemaining == 7)
print("PASS: first welcome starts one seven-day trial")

let active = freshState()
active.trialStartDate = Date().addingTimeInterval(-2 * 86_400)
let activeStart = active.trialStartDate
active.resetOnboarding()
active.completeOnboarding()
assert(active.trialStartDate == activeStart && active.isTrialActive)
print("PASS: replay preserves an active trial deadline")

let expired = freshState()
expired.trialStartDate = Date().addingTimeInterval(-8 * 86_400)
let expiredStart = expired.trialStartDate
expired.resetOnboarding()
assert(!expired.hasCompletedOnboarding && expired.trialStartDate == expiredStart)
expired.completeOnboarding()
assert(expired.hasCompletedOnboarding && expired.trialStartDate == expiredStart)
assert(!expired.isTrialActive && !expired.hasFullToybox)
print("PASS: replay cannot renew an expired trial")

let purchased = freshState()
purchased.accessTier = .fullToybox
purchased.trialStartDate = Date().addingTimeInterval(-8 * 86_400)
purchased.hiddenToyIDs = ["hum"]
purchased.windDownHour = 18
purchased.isSoundEnabled = false
let purchasedStart = purchased.trialStartDate
purchased.resetOnboarding()
assert(purchased.hasPurchasedFullToybox && purchased.trialStartDate == purchasedStart)
purchased.completeOnboarding()
assert(purchased.hasPurchasedFullToybox && purchased.hasFullToybox)
assert(purchased.trialStartDate == purchasedStart)
assert(purchased.hiddenToyIDs == ["hum"] && purchased.windDownHour == 18)
assert(!purchased.isSoundEnabled)
print("PASS: replay preserves purchase access and family preferences")
'''

with tempfile.TemporaryDirectory(prefix="lull-onboarding-check-") as directory:
    check = Path(directory) / "OnboardingStateCheck.swift"
    check.write_text(state_source + fixture)
    subprocess.run([
        "/usr/bin/swift", "-module-cache-path", str(Path(directory) / "ModuleCache"),
        str(check)
    ], check=True)
