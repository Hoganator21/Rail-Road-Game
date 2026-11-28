# Train Meets, Bottleneck Dispatch & AI Traffic (design spec, Nov 27)

FEATURE MODULE SPEC: TRAIN MEETS, BOTTLENECK DISPATCH & AI TRAFFIC
1. Track Topology & Bottleneck Chokepoints
 * Double-Track Mainline & Passing Sidings: Supports bidirectional CTC (Centralized Traffic Control) running on double-track segments, allowing trains to overtake slower tonnage or pass at track speed.
 * Double-to-Single Track Chokepoints: Key corridor bottlenecks—such as single-track bridge approaches (e.g., Weldon Viaduct) and single-track mainline segments—create natural traffic bottlenecks managed by the AI Dispatcher.
 * Train Priority Hierarchy: Every active consist on the corridor carries a dispatch priority class:
   * Priority Intermodal / Hotshot ("Money Trains"): Highest priority; holds the main and forces lower-tier trains into sidings or double-track hold points.
   * Manifest Road Freight: Standard mainline priority; yields to intermodals but takes precedence over locals.
   * Local Switchers & Light Power: Lowest priority; must clear the main and wait for open track windows between mainline movements.
2. Dynamic Meet & Pass Scenarios
 * Running Meets on Double Track:
   * Two opposing trains pass each other at track speed on adjacent mains.
   * Prototype Crew Detail: As an opposing train approaches at night, the player must dim their locomotive headlights to avoid blinding the opposing crew, exchange visual/radio roll-by inspections (watching the passing train for hotboxes, shifted loads, or dragging equipment), and restore bright headlights once clear.
 * Overtake Passes (Faster Train Passing Slower Tonnage):
   * When the player is hauling a heavy, slow manifest or working a local and a Tier 4 Priority Intermodal approaches from behind, the dispatcher routes the player into a passing siding (or holds them on Track 2) under Medium Approach / Restricting signals until the hotshot clears the block ahead.
 * Single-Track Bottleneck Holds (Waiting for the Single Iron):
   * When approaching a double-to-single track transition while an opposing train already occupies the single-track block, the player receives an Advance Approach → Approach → Stop signal progression at the control point.
   * The player must bring their consist to a controlled stop clear of the fouling point (and clear of highway grade crossings so they don't block town traffic), wait for the opposing train to clear the single-track switch, and watch the absolute home signal clear to Limited Clear / Medium Clear before throttling up onto the single track.
3. Integration with Time Compression & Radio Dispatch
 * Automatic Time-Compression Dropouts: If the player is using accelerated pass speed on an open stretch and approaches a scheduled meet, overtake, or single-track hold, the engine automatically steps back down to 1x real-time ahead of the first distant warning signal so the player never overshoots a red home signal.
 * Live Dispatcher Radio & Roll-By Calls:
   * The AI Dispatcher broadcasts realistic corridor radio chatter ("Dispatcher to Southbound 142, you're going in the hole at Bellwood for a northbound intermodal, hold short of the signal").
   * Opposing AI crews call out roll-by inspections over the road channel after passing ("Southbound 142, good roll-by on both sides, no defects noted"), tying directly into the wayside defect detector and train inspection loop.
