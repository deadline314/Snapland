# SG-18 fountain timing: design and implementation

Scope: SG-18, `fountain_timing`. Research material is the previously opened first-park survey; its pages were read as first-party public descriptions, not played as validation of this implementation. Design implications below are our own, not claims about internal source code.

## First-party references considered

- [Beat Saber — Beat Games, Steam](https://store.steampowered.com/app/620980/Beat_Saber/): its official description connects authored visual direction cues to music. Applied here by tying the central water jet, cue ring, hit window, and jump timestamp to one scheduled beat.
- [Super Mario Party Jamboree — Nintendo](https://www.nintendo.com/us/store/products/super-mario-party-jamboree-nintendo-switch-2-edition-plus-jamboree-tv-switch-2/): official feature text lists multiple input modalities across minigames. Applied here by routing Space and a left click through the same timing evaluator.
- [Celeste — Extremely OK Games / Maddy Makes Games, Steam](https://store.steampowered.com/app/504230/Celeste/): official description emphasizes a small readable action set and rapid retries. Applied here by keeping the round to three short, fixed opportunities and surfacing immediate timing feedback.
- [Simon instructions — Hasbro](https://instructions.hasbro.com/en-us/instruction/simon-game): official rules describe observing a signal then reproducing it. Applied here by separating a visible count-in/pre-cue from each input opportunity and showing the one-shot outcome.
- [New Pokémon Snap — Nintendo](https://www.nintendo.com/us/store/products/new-pokemon-snap-110735/): official store description explains that photo ratings are based on observable pose, size, and orientation. Applied here by recording each jump’s measured timing error and grade as a separate result row.
- [Portal 2 — Valve, Steam](https://store.steampowered.com/app/620/Portal_2/): official description presents puzzle elements introduced across test chambers. Applied here by teaching cue reading, equivalent input, then ordinary/bonus thresholds in separate tutorial steps.
- [Overcooked! 2 — Ghost Town Games / Team17, Steam](https://store.steampowered.com/app/728880/Overcooked_2/): official feature description calls out clear task flow. Applied here by making each of three scheduled jumps a discrete cycle: build → pre-cue → jump/land → result.

These sources were opened in the survey. Root subsequently reviewed native GPU captures at normal and quarter speed using real Input events in an isolated save: a two-hit/one-miss 500-point route and a separate three-perfect 900-point clear with earned photos and achievement visible in the live album. This is automated native input acceptance, not a human playtest or final art-quality approval.

## Rules

The round schedules three central-jet peaks at 1.00s, 2.35s, and 3.70s, each 1.35s apart. Central jet height reaches its visual maximum at the exact same timestamp as the score target. It rises into a distinct pre-cue, then the ring and label identify the jump window. A successful key or left click starts the same visible jump arc and records the signed error from that timestamp.

Each opportunity resolves once. A press before its pre-cue is feedback-only and cannot consume future opportunities; after the pre-cue, the first press resolves the active jump. A player who waits sees an explicit missed-opportunity result when the window closes. Repeated presses cannot spend later chances early. A slow frame resolves every deadline already passed, with no extra animation or input catch-up.

The third successful input records its score and grade immediately, but the result waits until the complete eight-frame, 12 FPS authored jump and a 70ms landing settle have finished. Pause freezes this pending landing just like the beat clock; resume continues the remaining animation/settle time without catch-up. A missed final opportunity can finish as soon as its deadline is resolved because no jump animation is pending. This keeps the final score and collection gates visible only after the character actually lands.

Normal timing grades are ±70ms = perfect / 300 points, ±160ms = accurate / 200, and ±220ms = landed / 100. Outside ±220ms, or no input, is a 0-point miss. Assist widens those boundaries to ±110ms, ±240ms, and ±340ms; it never supplies a jump. Ordinary eligibility remains the catalog requirement of three successful landings. Devil eligibility remains all three perfect. The score is independent from both sticker gates.

The result ledger holds one row per opportunity, including ordinal, grade, signed early/late deviation in milliseconds, and awarded points; missed chances get a zero-point row. HUD progress shows both opportunities resolved and successful landings. Reduced motion holds jet height and jump travel still while retaining the same changing pre-cue, text, ring, score, and judgement.

## Acceptance and limitations

`test_minigames.gd` exercises both edges of each grade boundary, Space/click equivalence, spam protection, no-input misses, two-hit failure, three-hit ordinary, three-perfect devil, assist-only widened tolerance, pause/resume phase freeze, reduced motion, and a 4.5s slow-frame deadline sweep. It also verifies that the final successful jump remains active through all eight frame intervals and the landing settle, and that pause does not consume pending finish time. A dedicated `test_fountain.gd` isolates the same timing and landing contract. The tutorial retains the existing screenshot paths but updates all three written steps to the implemented timing windows and collection gates.

Root should capture the first pre-cue, a normal ±100ms jump, a perfect jump, the miss outcome, and the result details panel in normal and reduced-motion sessions. Hands-on review should compare the visible central-jet maximum to jump feedback at normal speed; static/runtime checks cannot establish perceived sync or input feel.
