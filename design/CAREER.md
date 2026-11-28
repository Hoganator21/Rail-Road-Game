# Master Architecture & Game Design Plan (Nov 27, supersedes earlier career notes)

MASTER ARCHITECTURE & GAME DESIGN PLAN: PERSISTENT CAREER MODE, WORLD STREAMING & CORRIDOR REALISM
1. Core Vision & Scope
 * High-Level Concept: An endless, persistent North American freight railroad RPG and simulation ("GTA for trains without the violence") built in Godot 4 (Forward+), designed to surpass Train Sim World through operational depth, true mechanical consequences, and zero-bloat performance.
 * Starting Territory & Expansion: Anchored initially on the Seaboard A-Line corridor from Richmond, Virginia (Acca Yard, Fulton Yard, Bellwood Junction) to Rocky Mount, North Carolina, using modular data structures so territories, freight networks, and multiplayer/MMO infrastructure can scale outward over time.
 * Difficulty & Realism Presets: Configurable player sliders/presets (e.g., Assisted vs. Prototype Realism) governing brake pipe recharge rates, knuckle-break force thresholds, economy strictness, and failure recovery.
 * Control & Platform Targets: Built for PC and mobile with first-class physical gamepad/controller support (triggers/sticks mapped cleanly to throttle notches, independent/automatic brakes, and cab camera views).
2. World Streaming, Performance & Pacing Architecture
 * Frustum Culling & Chunk Streaming (No N64/Full-Map Load Bottlenecks):
   * Do not load the entire corridor into memory at once. Implement frustum culling so the GPU only renders geometry inside the active camera's field of view.
   * Pair frustum culling with asynchronous spatial chunk streaming and dynamic LOD proxies: keep a rolling high-detail memory buffer around the player's consist (so turning the camera around in the cab or looking back down the train renders instantaneously with zero pop-in), while distant terrain and scenery stream in as low-poly proxies.
 * True 1:1 Yard Scale vs. Compressed Mainline Time:
   * 1:1 Spatial Track Scale: Yards, wyes, switches, and industrial leads are built at strict 1:1 real-world scale so 10,000-ton consists and multi-unit locomotive sets fit naturally without dwarfing sidings or turnouts.
   * Playable Time Compression (4:1 Baseline + Accelerated Passes): Mainline corridor runs (e.g., Richmond to Rocky Mount) use a tunable compressed timescale (defaulting to ~4:1, turning an 8-hour real-world run into ~2 hours of manual driving) plus an optional time-acceleration mode for uneventful open-road stretches.
   * Automatic Real-Time Dropouts: Time acceleration automatically disengages and snaps back to 1x real-time whenever the train approaches speed-restricted zones, signal aspect changes, yard limits, siding meets, or wayside defect detector alerts.
3. Real-World GIS Terrain & Signature Corridor Landmarks
 * Public GIS, Elevation & Canopy Integration:
   * Generate corridor topography and track gradients from public elevation data (USGS 3DEP/SRTM) aligned with real-world rail right-of-way coordinates.
   * Layer public tree-canopy coverage and land-use GIS maps so towns, industrial zones, forests, and rural stretches match the actual Virginia–North Carolina geography (mirroring how open-world games like GTA evoke real-world locations).
 * Bespoke Signature Bridges & Infrastructure:
   * Major crossings along the A-Line must be custom-modeled to match their real-world structural profiles rather than using generic bridge assets—specifically:
     * James River Bridge (Richmond, VA)
     * Appomattox River Bridge (Petersburg, VA)
     * Weldon Viaduct / Roanoke River Bridge (Weldon, NC)
4. Automated Living Economy & Endless Career Loop
 * AI-Driven Background Economy: Industries, classification yards, and intermodal ramps operate on automated production/consumption schedules. Players do not micromanage factories; instead, the economy dynamically generates manifests and work orders as industries fill or deplete inventory.
 * Historical & Seasonal Economy Templates: Support selectable economic profiles (e.g., seasonal grain harvests, manufacturing surges, retail intermodal peaks, or historical freight eras) that shift commodity demand and traffic density across the network.
 * Long-Term RPG Progression & Milestones:
   * Track a persistent Service Record: lifetime mileage, ton-miles hauled, smooth-handling coupler force scores, fuel efficiency, and safety/incident history.
   * Award tiered prestige badges and long-horizon milestones (e.g., 50 / 500 / 10,000 completed subdivision runs, zero-incident heavy-haul streaks, and hazmat safety endorsements).
5. Gated Career Tiers & Operational Variety
Players earn certifications and rank before touching heavy mainline power:
| Career Tier | Core Gameplay & Duties | Authorized Motive Power & Consists |
|---|---|---|
| Tier 1: Yard Hostler & Trainee | Terminal hostling, spinning locomotives on wyes (e.g., Acca Wye), fueling/MU setup, assembling/blocking yard cuts, and light-power moves. | 4-axle switchers & GP-series road switchers; light engine movements only. |
| Tier 2: Local Freight & Industry Switcher | Short-haul branchline and industrial spur switching; picking up blocks, spotting cars at customer doors, and setting out bad-order cars. | 4-axle locomotives (mandatory for tight-radius spurs); short-to-medium mixed manifests. |
| Tier 3: Mainline Road Freight | Point-to-point terminal runs; requires coupling onto pre-blocked cuts in the yard, connecting air, running brake tests, and verifying EOT telemetry before departure. | 6-axle road locomotives (GE ES44AC, EMD SD40/SD44/SD70); heavy mixed freight & unit trains. |
| Tier 4: Priority Intermodal ("Money Trains") | High-speed, long-haul intermodal runs extending beyond standard home territory limits with strict schedule windows and high payout multipliers. | High-horsepower 6-axle road power with mid-train and rear Distributed Power Units (DPUs) on 3-mile, 10,000+ ton consists. |
 * Non-Revenue & Prep Operations: Work orders routinely include light-power (deadhead) runs to rescue trains or retrieve outlying cuts, as well as mandatory yard assembly and wye turns prior to mainline departure.
6. Deep Physics, Track Geometry & Wayside Defect Detectors
 * Coupler, Drawbar & Slack Physics: Heavy consists simulate dynamic slack run-in/run-out and drawbar tension. Reckless throttle notches, poor dynamic braking, or bad air-brake timing on 10,000-ton trains will snap knuckles, pull drawbars, or cause derailments—requiring the player (via Engineer/Conductor role switching) to inspect the train, set out bad-order cars, or call for relief.
 * Degraded Spur & Industrial Track Geometry: Mainline welded rail runs smooth, whereas industrial spurs simulate rotted ties, missing ballast, and uneven cross-level—producing heavy cab pitch, roll, low-speed hunting, and harmonic rock-off if players exceed 5–10 MPH spur limits.
 * Axle-Count & Minimum Curve Radius Restrictions: Six-axle road locomotives (ES44AC, SD70) are physically restricted from sharp industrial spur curves; forcing 6-axle trucks into tight bends causes flange binding, rail spread, or derailment, requiring players to use 4-axle power for local industry work.
 * Individualized Wayside Defect Detectors:
   * Detectors along the corridor vary by location rather than repeating identical units:
     * Dragging Equipment Detectors (DED)
     * Hot Bearing / Hot Wheel Detectors (HBD/HWD)
     * High/Wide Load Clearance Detectors (placed 10–15 miles ahead of narrow tunnels, truss bridges, or tight clearances)
   * Gameplay Response: When a detector broadcasts an automated radio defect alarm with axle count, the player must stop safely, inspect the flagged car, and either resolve the fault or set the car out at the nearest siding before hitting a clearance obstruction or derailing.
