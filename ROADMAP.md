# Seaboard A-Line Sim / Switch Challenge — Roadmap & Design Notes

Living notes for future updates. Nothing here is built yet unless marked **(done)**.

## Project & engine
- Godot 4.3, native PC (.exe) + Android (.apk / later Play Store) — **(done)**
- Controller / gamepad, touch and keyboard — **(done, build 13)**
- First corridor: **Seaboard A-Line, Richmond, VA → Rocky Mount, NC** (real FRA GIS track, elevation, trees, landmarks, bridges)

## Game modes
- **Career mode** — full progression: role selection, train handling, consist building, corridor operations.
- **Switch Challenge** — the "mini game" from the main menu: switch alignment, operating rules, points, high scores. **(playable)**
  - Needs: better pacing, escalating yard/rule complexity, tighter feedback loops.

## Locomotives, consists & rules
- Locomotives: SD40-type units, SD70s, wide-body cabs; long-hood / short-hood layouts.
  - In game now: GE ES44AC, EMD SD70ACe, EMD GP38-2 (short & long hood) **(done)**
- Diesel shop scene to browse and pick locomotives (next title-menu build).
- EOT device chosen as part of train setup.
- Pick a pre-built consist **or** build one yourself, checked against placement rules:
  - Loaded tank cars may not be next to flatcars without bulkheads (needs a buffer).
  - Oil / hazmat (e.g. chlorine) cars may not be next to the locomotives — buffer car(s) required.
  - Verify exact rules against 49 CFR 174.85 and railroad timetable / special instructions before finalizing.
- Car count, loaded/empty, tonnage, length, DPU affect physics **(done, build 12)**

## Roles, yard departure & coupling
- Choose **Engineer** or **Conductor**.
- Cutscene: crew leaves the yard office and boards the train.
- Bring the train up to a cut of cars (first version: stop at a set point rather than full manual shunting),
  conductor positions and a coupling sequence plays, then the crew re-boards and departs.

## Braking, physics, proximity & difficulty
- Proximity scoring: a controlled stop short of a switch — ideally right at the clearance point — scores highest.
- Emergency stops short of the switch still recover partial points, but less than a prototypical stop.
- Stopping distance depends on slack, tonnage, loaded/empty, car count, train length (tonnage/length/load **done**; slack later).
- **Easy:** emergency costs points but never derails; the train stops so you can line the switch and go.
- **Expert:** emergency carries derailment risk based on speed, weight/load and train dynamics; a derailment ends the run.

## Title / main menu
- Cinematic train title screen, floating menu, settings, profile **(done, build 14)**
- Pause → Main Menu / Save Game; Continue from title **(done, build 14)**
- Real sign-in (Google Play Games / Steam) for cloud saves.
- Game name: TBD ("High Iron" placeholder).

## Cab feel (from design notes, Nov 27)
- **Sound:** prime mover pitch by notch, turbo, air brake exhaust on set/release, dynamic brake grid fan, wheel/rail joints **(done)**.
  To add: slack run-in/run-out clunks; a distinct exhaust for independent vs automatic; cab rattles that rise with speed.
- **Motion:** speed sway and joint bumps **(done)**. To add: lurch when slack runs in or out, sway through switches, low engine vibration tied to notch.
- **Live screens:** brake pipe, main reservoir, tractive effort, EOT pressure, alerter countdown, PTC on live SubViewports **(done)**.
  To add: the new screen designs (cab_screens_design_v1).
- **Cab layout:** rebuild every cab from the Blender designs, with the nose/restroom door, entry door and conductor's desk or jump seat placed correctly (SD70ACe locked; GP38-2 in progress).
- **Engineer / conductor roles:** move between both seats inside the same shell.
- **Controls:** notched throttle 1-8, dynamic brake, reverser, 26L/CCB handles with detents and a metal click per notch;
  large drag zones for touch; thumbstick/trigger mapping on controllers (D-pad/buttons **done**).

## Cab realism, round 2 (Nov 27)
- **Glass:** two-layer windshield: dirt, a wiper-arc mask and streaks that show in low sun; faint reflections of gauges and screens at night.
- **Night lighting:** dark cab with local warm light: gauge and stand backlight, screen glow spilling on the desk, dim dome light. No flat bright interiors.
- **Conductor side, fully working:** desk, PTC display, radio handset, emergency brake valve, rear jump seat, correct sightlines; hand off between engineer and conductor.
- **Cold start and fault recovery:** back-wall breaker panel, isolation switch (start/run), fuel pump and control switches.
  After a penalty or emergency stop: handle to emergency, then full service, wait for the timer, then recover and reset the PCS. No magic reset key.
- **MU setup:** trailing units set up and isolated, MU and DPU linked from the cab.
- **Camera snap views:** gauges, PTC screen, conductor desk, lean out the side window (for switching and shoving), look back at the train.
- **Controller fine control:** triggers for brake lapping in small steps, detents felt as rumble; snap views on the stick or a hold-button menu.
