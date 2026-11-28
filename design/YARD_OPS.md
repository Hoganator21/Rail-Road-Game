# Yard & Switching Operations (design spec, Nov 27)

## Three-step protection sign
The field shortcut is the **"OK / 3" hand sign**: thumb and index finger in a circle, the other three fingers straight up (three-step).
- **Requesting three-step:** the conductor holds it up before stepping between cars (lace air, adjust a knuckle, knock off a handbrake).
  The engineer sets the independent, centers the reverser and drops the generator field.
- **Confirming:** the engineer flashes the same sign back through the cab side window. Both crew have visual confirmation before anyone fouls the track.
- Implement as a hand pose on the conductor rig and mirrored by the engineer at the cab window during close switching.
  (An earlier note suggested a hard-hat tap; the OK/3 sign replaces it.)

FEATURE MODULE SPEC: CONDUCTOR SHOVE-MOVE & HAND-SIGNAL SYSTEM
1. Operational Context & Role Mechanics
 * When It Triggers: Activated during yard switching, industrial spur spotting, or reverse/shove movements where the locomotive is pushing cars ahead of the cab (e.g., Acca Yard, Fulton Yard, Bellwood/Hopewell industrial leads).
 * Dual-Role Gameplay:
   * Playing as Conductor: The player physically mounts the side stirrup/grab irons on the leading end of the shoved cut ("riding the point"), holds on with one hand, and uses the free hand (plus radio car-count callouts) to guide the AI or human engineer.
   * Playing as Engineer: The player watches the AI Conductor riding the leading car (in clear line-of-sight or via cab mirrors/leaning out the cab window) and reacts directly to the conductor's hand/lantern animations alongside radio countdowns.
 * Visibility & Day/Night Switching:
   * Daylight: Bare-hand / gloved hand signals clearly visible against the car body.
   * Night / Low-Visibility / Fog: Conductor automatically switches to a lantern / switchman's flashlight, translating the exact same geometric hand motions into glowing lantern arcs (standard GCOR/NORAC rulebook lantern signals).
2. Standard Prototype Hand & Lantern Signal State Machine
| Signal / Command | Prototype Hand Movement (Day) | Lantern Movement (Night) | Gameplay / AI Engineer Response |
|---|---|---|---|
| Stop | Arm swung briskly horizontally across the body at waist/shoulder height (repeated until stopped). | Swung horizontally across the track/body in a wide arc. | Engineer immediately closes throttle and applies independent/automatic brake to bring consist to a halt. |
| Proceed / Forward (Away from Signal) | Arm raised vertically above head and moved in a steady vertical up-and-down or overhead circular motion. | Held high and moved vertically up and down. | Engineer notches up forward (pulling away from the conductor's position). |
| Back Up / Shove (Toward Signal) | Arm extended horizontally to the side and swung in a vertical circle at shoulder height. | Swung in a steady vertical circle at right angles to the track. | Engineer initiates or continues shove movement toward the coupling/spotting target. |
| Reduce Speed / Easy ("Steady") | Arm extended horizontally out to the side, palm down, pressed gently up and down ("patting the air"). | Held steady horizontally and moved slightly up and down. | Engineer drops throttle to Notch 1 / idle and feathers independent brake to 2–4 MPH coupling/spotting speed. |
| Apply / Release Air Brakes | Apply: Hand raised above head, palm forward, closed into a fist.
Release: Hand raised above head, palm waved side-to-side. | Held high and moved in a small horizontal circle above head (release). | Used during static yard air tests and brake pipe checks before departing a yard track. |
4. Technical & Animation Notes for Godot 4
 * IK & Attachment Points: Anchor the conductor's character rig to standardized Marker3D nodes on the leading freight car's side ladder/stirrup (point_ride_left / point_ride_right), with procedural Inverse Kinematics (IK) keeping one hand locked to the grab iron while the other hand executes the signal blend-tree.
 * Controller / Input Mapping:
   * On gamepad/controller (PC & mobile), map shove signals to a clean radial wheel or D-pad quick-bind while riding the point so the player can seamlessly transition from Back Up → Easy / Reduce Speed → Stop in the final two car lengths before coupling.
 * Safety Failure States: Riding the point inside tight-clearance structures (warehouse doors, close-clearance bridges, or adjacent fouled yard tracks) triggers a Close Clearance Warning—forcing the player to dismount and walk ahead on the ground before shoving through, or risk a catastrophic safety violation.


## Flat-yard kicking
1. **Prep:** close the angle cock behind the keeper cars and bleed the cut being kicked so its wheels roll free.
   DO NOT HUMP / DO NOT KICK cars (placarded hazmat such as chlorine, anhydrous, flammable gas, crude; autoracks; high-wide loads; occupied equipment) must be shoved to rest instead. Kicking one is a safety violation and a fine.
2. **The kick:** line the lead switch, give the kick signal, and the engineer throttles up to 4-8 mph depending on track length, wind and load.
   The conductor lifts the pin at the release point, then gives stop/washout and the engine brakes hard while the cut rolls free.
3. **Free roll:** rolling resistance depends on load, bearing temperature (cold grease is stiff), wind and bowl grade.
   - 2-4 mph coupling: clean joint, Switch Challenge bonus.
   - Short roll: the cut stalls and the track must be shoved together later.
   - Over 6-8 mph: lading damage, shifted loads, broken knuckles, or derailment.
4. **Switch tending:** don't line the next track until the last axle clears the points. Throwing a switch under a rolling car splits the switch and derails it.
5. **Later, as high-risk rule violations:** Dutch drops and flying switches.
