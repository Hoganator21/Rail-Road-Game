# Career Mode & Realism Architecture (design spec, Nov 27)

DESIGN SPECIFICATION HANDOFF: PERSISTENT CAREER MODE & REALISM ARCHITECTURE
1. Core Design Philosophy & Scope
 * Vision: An endless, persistent North American freight railroad RPG/simulation ("GTA for trains without the violence") that replaces linear, one-and-done scenario checklists with a living rail network.
 * Scalability: Built initially for single-player/local progression along the Seaboard A-Line corridor (Richmond, VA — Acca/Fulton/Bellwood yards — to Rocky Mount, NC), architected with clean data models so the world, freight network, and job dispatch systems can expand into a massive regional/multiplayer rail network over time.
 * Realism & Difficulty Scaling: Players can configure realism sliders/presets (e.g., Arcade/Assisted vs. Full Prototype Realism) affecting brake pipe recharge rates, knuckle-break thresholds, economy strictness, and failure consequences.
2. Automated World & Dynamic Freight Economy (AI-Driven)
 * Self-Simulating Background Economy: Industries, yards, and intermodal terminals along the corridor operate on automated production and consumption schedules—not player micromanagement.
 * Historical / Era Economy Templates: Economy algorithms can mimic past real-world economic cycles or seasonal freight surges (e.g., grain harvest rushes, industrial manufacturing booms, intermodal retail peaks), dynamically shifting commodity supply and demand across territories.
 * Contract Generation: As AI industries fill up or run low on raw materials, the dispatch board automatically generates realistic work orders and manifests without player intervention.
3. Career Progression & Operational Tiers (Gated Access)
Players do not start with access to high-tonnage mainline trains. Access is strictly gated by rank, certifications, mileage, and safety record:
| Tier / Role | Operations & Duties | Motive Power & Consist Limits |
|---|---|---|
| Tier 1: Yard Hostler & Trainee | Terminal hostling, spinning locomotives on the wye (e.g., Acca Wye), fueling/MU setup, light engine moves, and assembling/blocking yard cuts. | 4-axle switchers and road switchers (GP-series); light power only. |
| Tier 2: Local Freight & Industry Switcher | Short-distance branchline and industrial spur runs; picking up blocks, setting out bad-order cars, and spotting cars at customer sidings. | 4-axle locomotives (mandatory for tight-radius spurs); short-to-medium mixed manifests. |
| Tier 3: Mainline Road Freight | Point-to-point corridor runs between major terminals; requires assembling/picking up pre-blocked consists in the yard prior to departure. | 6-axle road power (GE ES44AC, EMD SD40/SD44/SD70); heavy mixed freight & unit trains. |
| Tier 4: Priority Intermodal ("Money Trains") | High-speed, long-haul intermodal runs extending beyond standard home territory limits with strict schedule windows and high payout multipliers. | High-horsepower 6-axle road units with Distributed Power Units (DPUs) in mid-train or rear configurations (up to 3-mile-long, 10,000+ ton consists). |
 * Pre-Departure & Non-Revenue Moves: Jobs are not instant-start mainline spawns. Depending on the work order, players must:
   * Hostle power out of the engine terminal and spin locomotives on a wye to face the correct direction.
   * Couple onto their assigned cut in the yard, connect air hoses, run brake tests, and verify End-of-Train (EOT) telemetry.
   * Run light power (deadhead) across territories to rescue trains or pick up outlying consists.
4. Long-Term Hooks, Milestones & RPG Progression
 * Operational Prestige & Certifications: Endorsements required to unlock heavier tonnage, hazmat handling (enforcing federal buffer-car rules for oil/chlorine), DPU radio fence operation, and dark-territory track warrants.
 * Tiered Career Milestones & Achievements: Long-horizon career records (e.g., 100 / 1,000 / 10,000 completed runs on specific subdivisions, zero-incident tonnage milestones, consecutive on-time priority intermodal streaks, fuel-efficiency ratings, and smooth-handling coupler force scores).
 * Persistent Service Record: Tracks lifetime mileage, ton-miles hauled, derailment/broken-knuckle incidents, and terminal reputation.
5. Deep Physics, Track Geometry & Failure Consequences
 * Drawbar & Coupler Stress Physics: Excessive throttle modulation, poor slack management on heavy grades, or improper dynamic braking on 10,000-ton consists causes real physical failures—broken knuckles, pulled drawbars, and separated air hoses requiring the player (in Engineer or Conductor role) to walk the train, replace knuckles/set out cars, or call for relief.
 * Degraded Spur & Industry Track Physics: Mainline welded rail runs smooth, whereas industrial leads and customer spurs simulate rotted ties, missing ballast, and uneven cross-level geometry—inducing heavy cab pitch, roll, low-speed hunting, and harmonic rock-off if players exceed restricted speeds (5–10 MPH).
 * Axle-Count & Curve Radius Restrictions: Six-axle road locomotives (SD70, ES44AC) are physically restricted from tight-radius industrial spurs; attempting to force 6-axle trucks into sharp industry bends causes severe flange binding, rail spread, or derailment, forcing players to swap to 4-axle power for local switching.
6. Wayside Defect Detectors (Dynamic Risk & Early Warning)
 * Varied Detector Types: Wayside detectors placed along the corridor are individualized rather than copy-pasted, simulating real railroad infrastructure:
   * Dragging Equipment Detectors (DED)
   * Hot Bearing / Hotbox & Hot Wheel Detectors (HBD/HWD)
   * High/Wide Load Clearance Detectors (placed 10–15 miles ahead of narrow tunnels, truss bridges, or tight clearances)
 * Operational Gameplay Loop: When a detector transmits an automated radio defect alarm with axle count, the player must bring the train to a safe stop, inspect the flagged car, and either correct the issue (e.g., release a sticking handbrake/cut out a brake valve) or set out the bad-order car at the nearest siding before reaching a fatal derailment or clearance strike.
