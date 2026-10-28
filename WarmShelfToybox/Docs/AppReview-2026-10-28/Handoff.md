## Final status — October 28, 2026, 3:46 PM CDT
Build 1.0 (17), Keep Forever, Lull Family yearly and the subscription group were resubmitted successfully; all four show Waiting for Review. Submission ID remains 6a0fb891-02a0-4692-b70c-e9d49264ad07. Manual release retained. Proof: resubmitted-build17.png.

Founder confirmed installing17 and provided recording https://drive.google.com/file/d/1fqQj2Dat1EfplcrZGr9hwe8hoQ-KMoyn/view . Founder explicitly requested no video inspection and directed submission. Video was NOT watched/verified. We made no independent transaction-verification claim. Exact sent message and saved notes are Reply-build17.txt / Review-Notes-build17.txt. Annual sandbox purchase was already active before recording per founder.

Patrick (dopatrie@icloud.com), already Account Holder/Admin, was added to the existing Fam internal TestFlight group. Earlier he was installing 1.1(15); 1.0(17) is accessed via Previous Builds. No account-role changes.

Search-results art was cancelled by founder; slot remains empty. Existing product header remains. New request: improve flat/"sad" screenshot backgrounds; keep submission in queue and prepare artwork separately.

---
Historical work log below (superseded by the final status above):

# Lull — October 28 purchase review fix

Branch: claude/modest-bell-cjarqm. Checkout: ~/Desktop/lull v.2.

## Verified Apple state
Apple reviewed 1.0 (16) on October 27 on iPad Air 11-inch (M3). The only current finding is 2.1(b): Keep Forever / Lull Family could not be found. The prior Guideline 4 gate/layout issue is no longer listed. Build 16 had been resubmitted October 22 at 9:46 AM. Privacy answers were posted October 22 at 9:33 AM.

Apple's screenshot is apple-purchase-finding.png. It shows the active Family subscription status card, with Manage subscription and Restore, but no product catalog. Code confirms render() previously displayed status OR offers, hiding both products whenever any entitlement existed. This explains the visible problem; it is NOT evidence that sandbox transactions have been completed successfully.

Both live product IDs match the binary: com.lull.family.yearly and com.lull.full.lifetime. Both are Ready for Review, attached to the submission, sale availability enabled (one region, the US launch plan); Family Sharing enabled. No products removed, prices changed, or subscriptions created.

## Build 17 changes
- Your plan retains the current status AND displays Plan options below it for existing subscribers/owners.
- Existing annual plan marked Current plan; lifetime owners see Already purchased / Already included. Duplicate purchase buttons disabled and purchase handler guards them too.
- Active subscribers can find and buy Keep Forever; copy explicitly says this separate purchase does not cancel the annual subscription and directs them to Manage subscription.
- Manage subscription remains accessible after lifetime purchase so a prior annual renewal can be cancelled.
- Active plans never display a new-free-trial timeline.
- All nine toys, previous build16 gate/iPad/Meadow/gesture fixes and new Wash vehicles retained.

## Evidence and remaining requirement
Debug build and all 8 onboarding-state scenarios pass. On iPad Air M3 simulator, active Family state now visibly shows both catalog cards, disabled Current plan, enabled Keep Forever, cancellation warning, and policy links. This uses DEBUG preview prices and a simulated entitlement, not a sandbox purchase. Signed Release archive succeeded. Lifetime-owner UI was also checked: both catalog cards remain visible with duplicate purchases disabled, and Manage subscription remains available. Upload succeeded October 28 at 15:13 CDT (EXPORT SUCCEEDED); Apple accepted the package for processing. Archive: /private/tmp/lull-review17-release/Lull.xcarchive. Upload log: /private/tmp/lull-review17-upload.log. Source/artwork commit: 9a96e84, pushed to origin.
The founder explicitly agreed to record the required physical-device sandbox purchase demonstration. Recording-guide.txt gives the sequence. Do not claim a successful sandbox purchase or physical-device test until the recording/confirmation arrives. Do not blindly resubmit with the old build14 video. App still has no app accounts; Apple's generic demo-account wording does not require adding accounts.

## Artwork — cancelled by founder
The founder decided against the search-results header on October 28. App Store Connect currently shows 0 of 1 Search Results Asset, so leave it empty. The existing product-page header is unchanged. Generated search artwork and its prompt remain in Docs/Marketing/2026-10-28/ as unused source files. Do not attach or submit it. The saved apple-search-preview.png is an earlier preview only, not the current draft state.

## Next
Build17 upload complete; founder records successful annual then lifetime sandbox flows (fresh test account), restore and brief gameplay. Add recording link and precise navigation/status explanation to review notes and reply, select17 and resubmit with the existing three purchase/group items. Keep manual release. No broad audit or unsolicited TestFlight notes/group verification.
