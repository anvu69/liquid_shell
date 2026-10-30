# P3b-2 spike S2: the native back swipe (VK-440, decides VK-444)

- **Plane:** VK-440 (this spike), VK-444 (decided here), parent VK-780.
- **Spec:** `docs/specs/2026-10-28-p3b2-page-bars-design.md` §7, §8.1. **Plan:** `docs/plans/2026-10-28-back-swipe-spike.md` (the probe code is there, as patches; it was never committed).
- **Date:** 2026-10-28 to 2026-10-30 (write-up 2026-10-30). **Branch:** `VK-440-back-swipe-spike`. **Time used:** about 3.1 h of the 2-day time box (16 h): Task 1 0.2 h, Task 2 1.2 h, Task 3 skipped, Task 4 0.8 h, Task 2b (B-observe re-run on new main) 0.4 h, Task 5 about 0.5 h. A first Task 4 attempt on 2026-10-29 died without results; its time is not counted.
- **Toolchain:** Flutter 3.44.6 (fvm 4.1.2), Xcode 27.1 (27A9275); debug builds (Flutter runs no profile build on simulators).
- **Bases:** the old base is main `e0bbf62` plus the spec and plan (branch at `fbb265a`). The new main is `d922744` (B2, PR #30) merged into the branch as `685e64a`. Task 4's raw files name the merge `f35d868`; that commit was replaced in history by `685e64a`, which has the same tree (`a8ddb6b`).

> **Tóm tắt (cho chủ sản phẩm).** Quyết định: **NO-GO**, thanh điều hướng native không thể đi theo ngón tay khi vuốt lùi trong 0.1.0 hay theo cách đã thử. Khi Flutter lái (B-observe), tiến độ khớp từng frame nhưng tiêu đề trên thanh nhảy ngay về trạng thái cuối, ở mọi máy và cả trên main mới; khi UIKit lái (A), UIKit kết thúc hoạt ảnh của nó 233–458 ms sau Flutter và cú vuốt cạnh sidebar trên iPad không tới được UIKit. Không cần thử gì trên máy thật: hành vi đang ship (thanh đổi khi cử chỉ kết thúc, các test chốt NO-GO của B2) giữ nguyên.

## Decision

**NO-GO.** No probe passed every blocking row on all pairs (spec §7.4).
- **Probe A** fails two rows however G2 and G1 numeric are weighed:
  - G4 on all four pairs: 0 commits in time; UIKit finishes its own pop animation 233–458 ms after Dart's commit, against a limit of 16.7 ms.
  - G5 on both iPads: an edge swipe beside the tiled sidebar reaches Flutter's own detector, never UIKit's recognizer. This is so by construction.
  - It also fails G3 on both iPads (UIKit committed releases at about 28 %), G2 on both iPads (weak, see the limits below) and G1 numeric on three pairs (one tick each).
- **B-observe** fails G1 visual on every pair it ran on, on both bases: four pairs on the old base, and iphone-26.5 and ipad-26.5 on new main. At the 45 % hold the pushed title is already gone, while UIKit's own pop shows it sliding out. `percentComplete` follows Dart's value frame for frame (G1 numeric passes everywhere), so the native bar does not follow a custom percent-driven interactive transition.
  - It also fails G4 on the iPads, on timing only: on new main ipad-26.5 had 13/20 commits in time, max 19.5 ms. On the old base it failed on three pairs (max 105.3 ms on ipad-27.0).
- **B-drive** was not run. It shares B-observe's native half, so it cannot pass G1 visual.

## Path taken (owner decisions)

- **2026-10-29: Task 3 (B-drive) skipped.** B-observe failed G1 visual, and B-drive shares that native half. Its G4 failure was timing only. The plan's Order was ambiguous with three failing rows: G4 alone said "run Task 3", while G1 visual and G2 said "skip it". The owner chose to skip it.
- **2026-10-30: Task 4 (probe A) re-run on new main.** B2 (PR #30) had merged by then, and a first Task 4 attempt on the old base had died without results. The branch merged `d922744`, and the probe patches were ported to B2's code (`applyPages(compact:)`, the new `init(root:search:)`). Probe intent was unchanged.
- **2026-10-30: B-observe re-run briefly on new main**, on iphone-26.5 and ipad-26.5 only (Task 2b), so that both probes stand on one base. The old-base B-observe numbers are kept below as the comparison.

## Question (spec §7.1)

Can the native navigation bar follow the user's finger during a back swipe on any tab, frame by frame, with Flutter's page, without any public API change?

## Setup

| Pair | Device | Runtime | Display rate measured |
|---|---|---|---|
| iphone-26.5 | iPhone 17 Pro | iOS 26.5 | 60 Hz (16.67 ms), every run |
| ipad-26.5 | iPad Air 11-inch (M4) | iOS 26.5 | 60 Hz (16.67 ms), every run |
| iphone-27.0 | iPhone 17 Pro | iOS 27.0 | 60 Hz (16.67 ms), every run |
| ipad-27.0 | iPad Air 11-inch (M4) | iOS 27.0 | 60 Hz (16.67 ms), every run |

Each agent created its own simulators and deleted them afterwards. The names were `vk440 sp1 …`, `b1-spike-t2-…`, `b1-spike-t4-…` and `b1-spike-obs-…`, so each task ran on different simulator instances. The swipes are XCUITest presses on the search tab's pushed page ("Nhạc Trịnh", example demo `search`): cancels released at 30 %, commits at 80 %, 500 pt/s, 20 each per pair. Holds stop at 45 % for 1.5 s and are recorded. On the iPads in landscape, the edge swipes start 2–18 pt right of the tiled sidebar. The log, the clean-tick rule and the two forms of G1 are as in the plan's "Measurement rules". Dart's frame time and the display link's target time agreed to the µs. In the B-observe runs, the clock `recv-frame` medians were 3.96–5.96 ms, so the pairing needs no clock offset.

## Probes run

| Probe | What | Ran | Notes |
|---|---|---|---|
| B-2 XCTest | the override against an interactive pop | yes: iphone-26.5, iphone-27.0 (old base, 2026-10-28) | 2/2 tests passed on both; identical `SPIKE-B2` lines. `spike-b2.patch` no longer applies to new main. |
| B-observe | the app's route gesture, forwarded per frame | yes: all four pairs on the old base (2026-10-29); iphone-26.5 and ipad-26.5 on new main (2026-10-30) | fails G1 visual on both bases; G4 on timing only. On new main there was no edge run (G5) and no 27.0 pairs. |
| B-drive | the shell's own drag through `PredictiveBackRoute` | skipped (owner, 2026-10-29) | it shares B-observe's native half, so it cannot pass G1 visual; G4 was timing only |
| A | UIKit's edge recognizer drives Flutter | yes: all four pairs on new main (2026-10-30), plus a cancel re-run on each iPad | fails G4 (all pairs) and G5 (by construction); also G3, G2 on the iPads and G1 numeric (one tick on three pairs) |

## B-2 (spec §7.2 step 4)

`runs/b2/iphone-26.5.txt`; `iphone-27.0.txt` is byte-identical (`sort -u` applied, so the order of the lines is not execution order):

```
SPIKE-B2 began popped=true interactive=true countDuring=1 topIsRoot=true
SPIKE-B2 end cancelled=false count=1 labels=Search@173.0/1.00
SPIKE-B2 end cancelled=true count=2 labels=Detail@178.0/1.00
SPIKE-B2 override before=false popped=false coordinator=false count=2 proposals=[
SPIKE-B2 p=0.00 percent=0.00 coordinator=0.00 labels=Search@173.0/1.00 Detail@178.0/0.00
SPIKE-B2 p=0.10 percent=0.10 coordinator=0.10 labels=Search@173.0/1.00 Detail@178.0/0.00
SPIKE-B2 p=0.20 percent=0.20 coordinator=0.20 labels=Search@173.0/1.00 Detail@178.0/0.00
SPIKE-B2 p=0.30 percent=0.30 coordinator=0.30 labels=Search@173.0/1.00 Detail@178.0/0.00
SPIKE-B2 p=0.40 percent=0.40 coordinator=0.40 labels=Search@173.0/1.00 Detail@178.0/0.00
SPIKE-B2 p=0.50 percent=0.50 coordinator=0.50 labels=Search@173.0/1.00 Detail@178.0/0.00
SPIKE-B2 p=0.60 percent=0.60 coordinator=0.60 labels=Search@173.0/1.00 Detail@178.0/0.00
SPIKE-B2 rest labels=Detail@178.0/1.00
```

The full proposals line, read from the test log before the xcresults were deleted, is `proposals=["popTo 1 0"]` on both runtimes. It and the pass counts rest on the Task 1 report.

The three readings:
1. **The override swallows a direct pop call.** A direct `popViewController(animated: true)` call with Dart's proposal installed returns nil, starts no transition (`coordinator=false`), keeps 2 hosts and sends `popTo 1 0`. The test calls the method directly; that UIKit's recognizer reaches the same call is inferred, not measured.
2. **Past the override, a percent-driven pop is interactive at once and follows `update`.** The test uses its own `SpikeTestPopDelegate` and animator, not UIKit's default pop.
   - UIKit's `transitionCoordinator.percentComplete` reads 0.00 to 0.60 in steps of 0.10.
   - `viewControllers` has already dropped the popped host when the transition starts (`countDuring=1`, sampled once).
   - `cancel()` ends with 2 hosts and `finish()` with 1.
3. **The bar's label layers prove nothing.** They read their end values from `p=0`, so the recordings decide the bar's look (the visual half below).

This ran on the iPhones only.

## Numbers per row (spec §7.4)

One table per probe and base; each cell gives that pair's values. "c / m" means cancel run / commit run; "e" is the iPad edge run.

### B-observe, old base (`e0bbf62`, 2026-10-29)

| # | Criterion | iphone-26.5 | ipad-26.5 | iphone-27.0 | ipad-27.0 | Result |
|---|---|---|---|---|---|---|
| G1 numeric | clean ticks: frames ≥ 2 apart (decides); Δ ≤ 0.02 share, max Δ; all ticks beside | 0 / 0; 100 % max 0.000 both; all ticks ≥2: 4 / 5 | 0 / 0 / e 0; 100 %, max 0.010 / 0.000 / 0.000; all ticks ≥2: 1 / 3 / 5 | 0 / 0; 99.9 % max 0.023 / 0.022; all ticks ≥2: 5 / 6 | 0 / 0 / e 0; 99.8–100 %, max 0.032 / 0.033 / 0.000; all ticks ≥2: 7 / 8 / 1 | PASS (the all-ticks misses are G2's jank) |
| G1 visual | bar mid-way at the 45 % hold, against UIKit's own pop | pushed title gone, "Search" at rest | pushed title gone | pushed title gone, "Search" at rest | pushed title gone | **FAIL** on all four |
| G2 | over-budget share (baseline), frames over 2 budgets, send p95 (debug) | 0.0 / 0.1 % (base 0.0); 0 / 1; 121 / 93 µs | 0.6 / 1.4 / e 0.4 % (base 0.4, limit 1.4); 0 / 2 / 3; 101 / 93 / 86 µs | 0.6 / 0.3 % (base 0.3); 2 / 3; 154 / 147 µs | **3.4** / 1.1 / e 0.3 % (base 1.1, limit 2.1); 10 / 4 / 0; 142 / 111 / 104 µs | FAIL on ipad-27.0 cancel (simulator rule; commit-only 10-swipe baselines). Profile numbers were not measured (NO-GO). |
| G3 | cancels ok / 20 | 20 | 20 | 20 | 20 | PASS |
| G4 | commits ok / 20; done−end range; proposals | 20; max 15.6 ms; 0 | 11 (e 12); max 23.2 (e 31.9) ms; 0 | 15; max 88.9 ms; 0 | 10 (e 7); max 105.3 (e 24.4) ms; 0 | **FAIL** on three pairs, timing only: every commit popped once (stack 2→1, `done cancelled=false count=1`), with no proposals or backs |
| G5 | edge swipes began / 20, G1 on them | — | 20, clean lag ≥2: 0 | — | 20, clean lag ≥2: 0 | PASS |
| G6 | Flutter's top inset moved mid-swipe (pt) | 0 | 2 (e 60, landscape) | 0 | 4 (e 54, landscape) | reported (a GO task) |
| G7 | jump at the end (recordings) | not judged | not judged | not judged | not judged | reported: 2 fps strips cannot show it |
| G8 | lifecycle reports other than resumed | 0 | 0 | 0 | 0 | PASS |
| G9–G11 | VoiceOver escape, refusing page, `PageView` | — | — | — | — | not measured (GO tasks) |

Harness misses: none (`began=20` in every run; `stuck=0 refused=0`).

### B-observe, new main (`685e64a`, 2026-10-30; 26.5 pairs only)

| # | Criterion | iphone-26.5 | ipad-26.5 | iphone-27.0 | ipad-27.0 | Result |
|---|---|---|---|---|---|---|
| G1 numeric | clean ticks: frames ≥ 2 apart (decides); Δ ≤ 0.02 share, max Δ; all ticks beside | 0 / 0; 99.8 % max 0.024 / 100 % max 0.000; all ticks ≥2: 4 / 3 | 0 / 0; 100 % max 0.010 / 99.9 % max 0.033; all ticks ≥2: 1 / 0 | not re-run | not re-run | PASS |
| G1 visual | bar mid-way at the 45 % hold, against UIKit's own pop | pushed title gone, "Search" at rest, circle half faded | pushed title gone, circle at full opacity | not re-run | not re-run | **FAIL** on both |
| G2 | over-budget share (baseline), frames over 2 budgets, send p95 (debug) | 0.1 % (base 0.0) / 0.0 % (base 0.0); 0 / 0; 105 / 89 µs | 0.6 % (base 0.0) / 0.9 % (base 0.2); 0 / 0; 98 / 102 µs | not re-run | not re-run | PASS (simulator rule, 20 + 20 swipe baselines on the same instance). Profile numbers were not measured (NO-GO). |
| G3 | cancels ok / 20 | 20 | 20 | not re-run | not re-run | PASS |
| G4 | commits ok / 20; done−end range; proposals | **20**; 9.5–15.5 ms, median 13.3; 0 | **13**; 9.1–19.5 ms, median 15.6, the 7 misses 16.7–19.5 ms; 0 | not re-run | not re-run | **FAIL** on ipad-26.5, timing only; structure right on all 40 commits |
| G5 | edge swipes began / 20, G1 on them | — | not re-run | — | not re-run | not re-run (owner scope) |
| G6 | Flutter's top inset moved mid-swipe (pt) | 0 | 2 (portrait; no edge run) | not re-run | not re-run | reported (a GO task) |
| G7 | jump at the end (recordings) | not judged | not judged | not re-run | not re-run | reported |
| G8 | lifecycle reports other than resumed | 0 | 0 | not re-run | not re-run | PASS |
| G9–G11 | VoiceOver escape, refusing page, `PageView` | — | — | — | — | not measured (GO tasks) |

Harness misses: none.

### A (UIKit drives Flutter), new main (`685e64a`, 2026-10-30)

| # | Criterion | iphone-26.5 | ipad-26.5 | iphone-27.0 | ipad-27.0 | Result |
|---|---|---|---|---|---|---|
| G1 numeric | clean ticks: frames ≥ 2 apart (decides); Δ ≤ 0.02 share, max Δ; all ticks beside | **1** / 0; 52.7 % max 0.260 / 36.5 % max 0.764 | 0 (rerun 0) / **1**; 57.8 % max 0.667 / 65.6 % max 0.225 | 0 / **1**; 51.5 % max 0.260 / 35.8 % max 0.764 | 0 (rerun 0) / 0; 43.3 % max 0.727 / 65.2 % max 0.234 | **FAIL** on three pairs, one tick each out of about 1100–1800. The Δ form fails everywhere because Flutter runs one frame behind UIKit. |
| G1 visual | bar mid-way at the 45 % hold, against UIKit's own pop | follows (it is UIKit's own pop) | follows | follows | follows | PASS |
| G2 | over-budget share (baseline), frames over 2 budgets, send p95 (debug) | 0.0 / 0.3 % (limit 1.0); 0 / 2; 153 / 115 µs | **3.2** (rerun 2.1) / 0.8 / e 0.1 % (limit 1.4); 0 / 0 / 0; 143 / 120 / 118 µs | 0.0 / 0.1 % (limit 1.3); 0 / 0; 136 / 155 µs | **9.1** on 33 frames (rerun 3.1) / 1.9 / e 0.5 % (limit 2.1); 3 / 5 / 0; 177 / 153 / 102 µs | FAIL on both iPads' cancel runs (simulator rule against the old-base commit-only baselines; weak). Profile numbers were not measured (NO-GO). |
| G3 | cancels ok / 20 | 20 (+2 UIKit cancels in the commit run) | **5 of 6** began, rerun **8 of 9** | 20 (+2) | **0 of 1**, rerun **3 of 4** | **FAIL** on both iPads: UIKit committed releases at 0.27–0.28, and each commit ended its run |
| G4 | commits ok / 20; done−end range; proposals | **0** (18 commits, 2 cancelled by UIKit at 78 %); median 240 ms; 0 | **0** / 20; median 300 ms; 0 | **0** (18 + 2 cancelled); median 239 ms; 0 | **0** / 20; median 288 ms; 0 | **FAIL** on all four: done−end 233–458 ms. The structure is right (stack 2→1, `done cancelled=false count=1`, no proposals or backs). |
| G5 | edge swipes began / 20, G1 on them | — | 20 began in Flutter, **0** native ticks (`stuck=20`) | — | 20 began in Flutter, **0** native ticks | **FAIL** (by construction: the touch never reaches UIKit's 20 pt strip) |
| G6 | Flutter's top inset moved mid-swipe (pt) | 0 | 0 | 0 | 0 | reported (a GO task) |
| G7 | jump at the end (recordings) | not judged | not judged | not judged | not judged | reported |
| G8 | lifecycle reports other than resumed | 0 | 0 | 0 | 0 | PASS |
| G9–G11 | VoiceOver escape, refusing page, `PageView` | — | — | — | — | not measured (GO tasks) |

Harness misses: none on the iPhones. The iPad cancel runs ended early (6, 9, 1 and 4 swipes) because UIKit committed a 30 % release and the following swipes started on the root. These are UIKit's decisions, not harness misses.

Old-base comparison for A: on iphone-26.5 (`oldbase/`), a dead first attempt on 2026-10-29 left 3 clean ticks ≥ 2 apart in the commit run, 19 commits / 1 cancel and done−end about 250 ms. It is the same picture, so B2 did not change probe A.

## Limits of the evidence

None of these can turn the decision. A's G4 and G5 and B-observe's G1 visual each fail on their own.

- **G1 visual rests on single held frames.** Each probe and pair is judged from one frame cut at about 45 % from a 2 fps sequence (`*-held.png`). The 3 holds per run were judged alike in the strips. B-observe's new-main frames were compared with Task 4's new-main UIKit recordings, made on another simulator instance of the same device and runtime.
- **G2 is a debug-build, simulator reading.** Its iPad samples are thin: A's iPad cancel runs have 33–281 frames, and its baselines are old-base, commit-only 10-swipe runs from other simulator instances. B-observe's old-base failure (ipad-27.0 cancel, 3.4 %) had no cancel baseline. On new main, against a like-for-like baseline, B-observe's G2 passes.
- **B-observe on new main ran on the 26.5 pairs only, with no edge run.** The 27.0 pairs (where the old base had the 89 and 105 ms G4 outliers and the G2 failure) and G5 were not re-run.
- **Mixed instances and bases.** Every task used its own simulators. B-observe has an old-base set (four pairs) and a new-main set (two pairs); A has new main only, plus one old-base pair.
- **B-observe's G4 is a strict one-frame rule on a debug simulator.** On new main the iPad misses are within 3 ms of it. It was not the deciding row.
- **UIKit's own commit threshold** differs by OS near 45 %. UIKit's own pop committed the 45 % hold release on the iPads on both bases (`N commit 0.432`) and on old-base iphone-26.5; the other iPhone runs returned all 3 holds. The reference frames were captured mid-hold before the release, so this does not touch G1 visual.

## The visual half of G1

Reference, UIKit's own pop (probe A's hold recordings, new main): on every pair the bar follows. The pushed title "Nhạc Trịnh" slides toward the trailing edge with the page. The previous "Search" title (iPhone) or the search root's field (iPad) slides in at the leading edge. The back circle cross-fades on the iPhone and stays at full opacity on the iPad. Strip and frame:
- iphone-26.5: `uikit-hold.png`, `uikit-held.png` = strip frame 33.
- ipad-26.5: `uikit-hold.png`, `uikit-held.png` = frame 34.
- iphone-27.0: `uikit-hold.png`, `uikit-held.png` = frame 50.
- ipad-27.0: `uikit-hold.png`, `uikit-held.png` = frame 68.

The old-base references in `runs/<tag>/oldbase/` show the same.

B-observe, at the same hold with the Flutter page about 40–45 % across:
- **iPhones (both bases, both runtimes):** the pushed title is gone (end state). The previous large title "Search" sits at rest at full opacity (end state). The back circle is half faded over "Search", or shown over it. → does not follow.
  - Frames: `iphone-26.5/observe-held.png` (strip frame 28), `iphone-27.0/observe-held.png` (frame 49), `iphone-26.5-observe-newmain/observe-held.png` (frame 33).
- **iPads (both bases, both runtimes):** "Nhạc Trịnh" is gone (end state). The back circle is at full opacity, as in the reference. The previous page has no bar title; its field moves with the Flutter page. → does not follow.
  - Frames: `ipad-26.5/observe-held.png` (frame 31), `ipad-27.0/observe-held.png` (frame 67 of the 2 fps sequence; its 6×20 strip `observe-hold.png` stops at frame 119 of a 66 s video, so cite the held frame), `ipad-26.5-observe-newmain/observe-held.png` (frame 33).

B2's bar rework (a native bar on every tab, large titles) did not change this: the new-main frames match the old-base frames.

## UIKit and Flutter calls that worked (or why not)

- **Flutter, observing:**
  - `NavigatorState.userGestureInProgressNotifier` marks a swipe from start to the end of its settle animation; the route's `isActive` at the end tells a commit from a cancel.
  - `1 − route.animation.value`, read in a post-frame callback, is the value that frame drew.
  - `SchedulerBinding.currentSystemFrameTimeStamp` equals `CADisplayLink.targetTimestamp` of the same frame (both `CACurrentMediaTime`).
  - `PlatformDispatcher.frameData.frameNumber` pairs a frame with its `FrameTiming`.
  - Nothing on the observing side failed: G1 numeric's clean form passed on every B-observe CSV on both bases, and the per-frame message cost 86–154 µs at p95.
- **Flutter, driving** (B-drive, A): `handleStartBackGesture(progress: 1)`, `handleUpdateBackGestureProgress`, `handleCancelBackGesture`; commit with `navigator.pop()`, then `didStopUserGesture()` once the route's animation is dismissed. B-drive was skipped. In probe A these calls drove the route from UIKit's percent:
  - Every commit and cancel was structurally right: one pop, no proposals or backs.
  - Flutter drew one frame behind UIKit (Δ form 36–66 % within 0.02).
  - The release (G7) was not judged.
- **UIKit, probe B:**
  - a bypass flag past `proposePop`;
  - a `UINavigationControllerDelegate` returning an animator that moves only the clear hosts, plus a `UIPercentDrivenInteractiveTransition`;
  - `update` per message; `finish()` / `cancel()` at Flutter's end;
  - a config arriving mid-swipe deferred until `transitionCoordinator.animate(alongsideTransition:completion:)` ends;
  - **UIKit's bar does not follow a custom interactive transition.** `percentComplete` tracks Dart's value on clean ticks with no frame 2 apart, yet the bar's titles sit at their end states from the start (the visual half above; B-2's label layers already read end values). `finish()` lands within a frame on the iPhones on 26.5. It lands 1–6 frames late on the iPads and on old-base 27.0.
- **UIKit, probe A:**
  - `PassThroughView` gives the leading 20 pt of a pushed page to UIKit;
  - `interactivePopGestureRecognizer` passes the override while `.began`/`.changed`;
  - `transitionCoordinator.percentComplete` is read per display frame;
  - `notifyWhenInteractionChanges` gives the end;
  - UIKit makes its own decisions, and Flutter cannot meet them in time.
    - UIKit decides commit or cancel by its own rule: it committed 0.27–0.28 releases on the iPads and cancelled 78 % releases on the iPhones (2 of 20 per runtime).
    - It then runs its own completion animation, so the native stack settles 233–458 ms after Dart's commit.
  - The tiled sidebar leaves no edge (B-3): the iPad edge swipes began in Flutter's own detector, and UIKit's recognizer saw none of them (0 native ticks on 40 swipes).

## What the decision changes (spec §7.6)

**NO-GO.** Nothing more. B2's NO-GO guards are the shipped behaviour (merged in PR #30, `d922744`). VK-444 closes with this write-up. The README keeps "the native back swipe does not follow the finger". A finger-tracked swipe goes to the 0.1.x backlog as "a later Flutter or another native approach". "UIKit drives Flutter" ran here as probe A and failed G4 and G5, so it is not the follow-up spike spec §7.3 describes for a NO-GO without probe A.

## VK-444

NO-GO: VK-444 is done with this write-up. Its NO-GO guards shipped in B2 (spec §8.2, PR #30). No `VK-444-swipe-sync` branch follows.

## Owner steps (real devices; agents never touch them)

None: a NO-GO needs none.

## Recordings and logs (not in the repository)

They were made under `build/spike/` of the B1 worktree (git-ignored), then deleted with it after this write-up.
- The small files are archived outside the repository, in `vankhan/.superpowers/sdd/b1-spike-archive/` (204 files, 16 MB), keeping the `runs/` layout. Everything except the videos was kept: the patches (`spike-b2.patch`, `spike-core.patch`, `spike-harness.patch`, `spike-core-newmain.patch`, `spike-harness-newmain.patch`, `old-base-applied.diff`), `spike_analyze.dart`, `run.sh`, `record.sh`, the helper and pair files, `time.txt`, and `runs/verdict-observe.txt` and `runs/verdict-uikit.txt`.
- The `*-hold.mp4` recordings (about 30–42 MB each) were deleted and are not archived.

Per pair, under `runs/<tag>/`, with `<tag>` = `iphone-26.5`, `ipad-26.5`, `iphone-27.0`, `ipad-27.0`:
- **B-observe, old base:**
  - `spike-observe-{cancel,commit,hold}.csv`, plus `spike-observe-edge.csv` on the iPads
  - `spike-timings-commit.csv`
  - `observe.txt`, `timings.txt`, `visual.txt`
  - `observe-hold.mp4` (deleted), `observe-hold.png`, `observe-held.png`
  - `observe*.log`, `timings.log`
- **A, new main:**
  - `spike-uikit-{cancel,commit,hold}.csv`, plus `spike-uikit-edge.csv` on the iPads
  - `uikit.txt`, `uikit-run.txt`, `uikit-record.txt`
  - `uikit-hold.mp4` (deleted), `uikit-hold.png`, `uikit-held.png`
  - `uikit*.log`
  - the old-base UIKit reference in `oldbase/` (all four pairs; iphone-26.5 also has the dead attempt's `uikit.txt` and CSVs)
- **A, iPad cancel re-runs:** `runs/ipad-26.5-rerun/` and `runs/ipad-27.0-rerun/`, each with `spike-uikit-cancel.csv`, `uikit.txt` and `uikit.log`.
- **B-observe, new main:** `runs/iphone-26.5-observe-newmain/` and `runs/ipad-26.5-observe-newmain/`, each with:
  - `spike-observe-{cancel,commit,hold}.csv`, `spike-timings-{cancel,commit}.csv`
  - `observe.txt`, `timings.txt`, `visual.txt`
  - `observe-hold.mp4` (deleted), `observe-hold.png`, `observe-held.png`
  - the `*-run.txt`, `*-record.txt` and `*.log` files
- **B-2:** `runs/b2/iphone-26.5.{txt,log}` and `runs/b2/iphone-27.0.{txt,log}`.
