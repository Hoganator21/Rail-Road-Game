# Switch Challenge — Seaboard A-Line (GPS-Projected Corridor Build)

## Real Corridor Landmarks Wired Into `data/a_line_route.json` & `index.html`
- **Acca Yard (Richmond, VA)**: `37.5900, -77.4758` — Starting / staging yard hub north of central Richmond
- **Bellwood Sub James River Bridge**: `37.5314, -77.4317` — Plate-girder crossing over the James River & Norfolk Southern line
- **Fulton Yard (Richmond, VA)**: `37.5107, -77.4085` — East-side yard complex toward the James River / Peninsula approach
- **Bellwood Yard / Junction (VA)**: `37.4280, -77.4480` — Southbound branch / Bellwood & Hopewell sub connection (MP S8.0)
- **Rocky Mount Station / A-Line**: `35.9380, -77.7977` — Southern corridor anchor in Rocky Mount, NC (near Charlie Baker interlocking `35.9314, -77.7997`)

## Features Included
- **GPS-to-3D World Projection**: Converts real latitude/longitude anchors relative to Acca Yard (`37.5900, -77.4758`) into scaled 3D corridor geometry with a James River water channel + plate-girder bridge, Fulton Yard lead, Bellwood Junction, and Rocky Mount / Charlie Baker interlocking approach.
- **High Overhead Clearances (`7.8m` above railhead)**: Overhead gantries and sign trusses clear auto racks and double-stack intermodal cars cleanly.
- **Free-Look & Signal Zoom Camera**: Left-drag to look around even while zoomed on signals; right-drag or WASD to pan; mouse wheel or Zoom +/- to adjust FOV.
- **Trackside Interlocking Huts**: Placed strictly at `±4.45m` lateral offset outside track clearance.
- **Detailed Rolling Stock & Train Air Mechanics**: Tank, Box, Flat, Intermodal, Bulkhead, Hopper, Auto Rack, and Gondola cars with flanged wheels seated on the railhead, pivoting trucks, knuckle couplers, angle cocks, gladhand air hoses, and brake pipe/cylinder physics.
