# Switch Challenge & A-Line Freight Sim - Overview (Nov 28)

## Core concept & world
- Persistent, realistic freight rail sim in Godot 4 (Forward+), PC + mobile, controller support.
- Richmond -> Rocky Mount (Seaboard A-Line): Acca Yard + wye, Fulton Yard, Bellwood, Hopewell, Weldon (Portsmouth Sub junction);
  James / Appomattox / Roanoke (Weldon) bridges.
- Real GIS / elevation terrain, frustum culling, chunk streaming.
- **Fictional railroad branding and liveries** (no real-railroad trademarks).
- Mobile: small base app + downloadable content packs (locomotives, regions, rolling stock, Ultra textures). No detail cut for size.

## Cabs, exterior & ground operations
- Cabs: GP38-2 (yard/local), SD70ACe, GE ES44AC wide cab with Smart/IFD displays. (Designed and in game, build 21.)
- **Nose-to-platform transition:** step from the cab out the nose door to the walkway, ladders down past the trucks to the ballast.
- Ground switches: manual hand-throw switch stands (harp and banner targets) and **power switch machines**.
- Conductor: shove signals, lantern signals at night, car counts on the radio, wye moves.
- Three-step sign: primary is the **OK / 3** sign (thumb and index finger circle, other three fingers up); the hard-hat tap is an alternate. See YARD_OPS.md.

## Signals, meets & yard kicking
See SIGNALS.md, TRAFFIC.md, YARD_OPS.md.

## Territory handoffs, traffic & air brakes (new)
- **Inbound territory handoffs and wyed power:** crews take inbound trains from adjacent territories at the yard, park or cut the engines,
  and spin locomotives on the wye when the lead unit lacks the signal/PTC programming for the next territory.
- **Main-line-only priority traffic:** intermodal and Amtrak run on the main, not through the yard. Amtrak is AI only for now (no playable passenger mode).
- **Air hose coupling and angle cocks:** occasional hose separations on the main (from detector stops or slack) mean lacing the hoses and
  opening the angle cock gradually, especially on 10+ car cuts, so the train equalizes without going into emergency.
- **Yard air and cut handovers:** a cut on yard air means it was already brake-tested (no full inspection). Disconnect plant air,
  couple the power, cut in the train air carefully, and handle bottled air cleanly when linking back in.
