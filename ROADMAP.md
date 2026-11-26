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
