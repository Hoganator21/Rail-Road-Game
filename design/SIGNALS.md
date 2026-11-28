# Seaboard A-Line Signal System & Signal School (design spec, Nov 27)

> Verify aspect names and speeds against the current CSX Operating Rules and timetable special instructions before implementing.

FEATURE MODULE SPEC: SEABOARD A-LINE SIGNAL SYSTEM & INTERACTIVE SIGNAL SCHOOL
1. Corridor Signal Architecture (Seaboard A-Line Heritage + CSX Rules)
 * Authentic Mast & Aspect Styling:
   * Mainline (Richmond, VA – Rocky Mount, NC): High-mast and cantilever color-light signals (classic Seaboard vertical 2- and 3-head arrangements, including staggered heads on older Seaboard Coast Line installations and modern vertical-aligned CSX heads).
   * Number Plates vs. Absolute Signals:
     * Intermediate (Permissive) Signals: Equipped with a number plate on the mast. A Red aspect (Stop and Proceed / Restricting under modern rules) allows the train to proceed at Restricted Speed (not exceeding 15–20 MPH, prepared to stop within half the range of vision) without dispatcher permission.
     * Home / Control Point (Absolute) Signals: No number plate (at interlocking junctions, yard exits like Acca/Fulton/Bellwood, and siding ends). A Red aspect is an absolute STOP—passing it without a dispatcher verbal authority / Form EC-1 triggers an immediate emergency PTC penalty brake application, a catastrophic safety violation, and career demotion.
 * Branchline Dark Territory (e.g., Portsmouth Subdivision):
   * Non-signaled territory governed strictly by Track Warrants / EC-1 authorities and manual switch-target indicators, contrasting sharply with the signaled double-track/CTC A-Line mainline.
2. Core Seaboard / CSX Signal Aspects & Speed Enforcement
Players must read multi-head aspects and comply with both the current signal speed and the next signal's approach speed:
| Signal Aspect (Top / Middle / Bottom) | Aspect Name | Operational Rule & Required Player Action |
|---|---|---|
| Green (over Red/Dark) | Clear | Proceed at Maximum Authorized Track Speed (MAS). |
| Yellow over Green | Approach Limited | Proceed approaching next signal at Limited Speed (45 MPH). |
| Yellow over Yellow | Advance Approach | Proceed prepared to stop at the second signal ahead; begin throttling down heavy consists immediately. |
| Yellow (over Red/Dark) | Approach | Proceed prepared to stop at the next signal; trains exceeding 30 MPH must immediately reduce speed to 30 MPH or less. |
| Red over Green | Limited Clear | Proceed at Limited Speed (45 MPH) through diverging turnout/crossover, then resume track speed once rear of train clears turnout. |
| Red over Yellow | Medium Approach | Proceed through turnout at Medium Speed (30 MPH) prepared to stop at next signal. |
| Red over Flashing Red (or Lunar) | Restricting | Proceed at Restricted Speed (max 15–20 MPH, prepared to stop short of train, broken rail, or misaligned switch within half range of vision). |
| Red (all heads Red, No Number Plate) | Stop | Absolute Stop before the signal mast. Overrunning causes an instant PTC penalty & critical safety failure. |
| Red (with Number Plate) | Stop and Proceed / Restricted | Come to a stop (or proceed per rulebook at Restricted Speed max 15 MPH) watching for occupied block ahead. |
3. Interactive "Signal School" & Career Qualification Gate
 * No Passive Rulebook Walls of Text: Players learn Seaboard A-Line signals hands-on before being certified for Tier 3 Mainline Road Freight or Tier 4 Priority Intermodal runs:
   * In-Cab / HUD Training Mode (Assisted Preset): Displays a subtle, toggleable aspect decoder tooltip when approaching signals during early trainee runs, highlighting the target speed and braking distance needed for the current train tonnage.
   * Interactive Signal Qualification Exam (Career Gate): Before unlocking Mainline Road certification, the player completes a practical simulator evaluation—both identifying live signal aspects under changing weather/night conditions and executing real braking curves on a loaded freight train to hit Approach (30 MPH) and Limited Clear (45 MPH) turnouts without overspeeding or snapping a knuckle.
   * Prototype Mode (Unassisted): Turns off all signal HUD prompts; players must rely strictly on reading the physical wayside masts, cab signal / PTC display (where equipped), and timetable special instructions.
4. Gameplay & Physics Integration
 * Tonnage-Aware Braking Curves: Because a 10,000-ton manifest takes over a mile to slow down, seeing an Advance Approach (Yellow/Yellow) or Approach Limited (Yellow/Green) requires immediate dynamic brake setup and minimum air reduction—waiting until the Approach (Yellow) signal guarantees an overrun.
 * Conductor Role Signal Callouts:
   * When playing as Engineer, the AI Conductor calls out every wayside signal across the cab ("Clear signal, Milepost 14!", "Approach—30 MPH, coming down!") and requires the Engineer to repeat/acknowledge restrictive aspects (mirroring real-world crew resource management).
   * When playing as Conductor, the player calls out the wayside signals to the AI Engineer; failing to call a restrictive signal in time causes the AI Engineer to react late, risking an overspeed penalty or emergency stop.
 * PTC / Alerter Enforcement: On PTC-equipped locomotives (ES44AC, modern SD70s), exceeding the signal's target braking curve triggers an audible predictive enforcement warning on the IFD screen; failing to reduce speed triggers a full-service/emergency PTC penalty brake application.

> **Correction (Nov 27):** the Portsmouth Subdivision branches off the A-Line at **Weldon, NC** and runs as dark territory (track warrants).
> It is on the corridor. The Weldon junction is where players leave signaled CTC for dark territory.
