// Real-world GIS track geometry extracted from OpenStreetMap / FRA North American Rail Network
// Seaboard A-Line (CSX Bellwood & North End Subdivisions) + Clifton Forge / Rivanna Wye & Hopewell Sub
const GIS_CORRIDORS = {
  aline_main: {
    name: "Seaboard A-Line (Acca Yard to Rocky Mount)",
    waypoints: [
      { mp: 0.0,   name: "Richmond Acca Yard (North)", lat: 37.5792, lon: -77.4795, limit: 15, signal: "CLEAR" },
      { mp: 1.4,   name: "Acca South Wye (Clifton Forge Jct)", lat: 37.5615, lon: -77.4712, limit: 25, signal: "CLEAR", wye: true },
      { mp: 4.8,   name: "James River Bridge / South Yard", lat: 37.5198, lon: -77.4480, limit: 35, signal: "CLEAR" },
      { mp: 9.2,   name: "Bellwood Wye Junction", lat: 37.4601, lon: -77.4368, limit: 40, signal: "APPROACH", wye: true },
      { mp: 15.6,  name: "Chester Siding", lat: 37.3685, lon: -77.4221, limit: 50, signal: "CLEAR" },
      { mp: 23.4,  name: "Petersburg (Collier Yard)", lat: 37.2134, lon: -77.4115, limit: 30, signal: "CLEAR" },
      { mp: 42.0,  name: "Carson / Stony Creek", lat: 36.9532, lon: -77.3991, limit: 60, signal: "CLEAR" },
      { mp: 63.5,  name: "Emporia Diamond (NS Crossing)", lat: 36.6860, lon: -77.5425, limit: 45, signal: "APPROACH" },
      { mp: 84.0,  name: "Weldon / Roanoke River Viaduct", lat: 36.4255, lon: -77.5988, limit: 50, signal: "CLEAR" },
      { mp: 105.5, name: "Enfield Siding", lat: 36.1812, lon: -77.6672, limit: 60, signal: "CLEAR" },
      { mp: 124.2, name: "Rocky Mount Terminal (South End)", lat: 35.9382, lon: -77.7905, limit: 15, signal: "STOP" }
    ]
  },
  bellwood_sub: {
    name: "Bellwood Subdivision (Acca to Hopewell)",
    waypoints: [
      { mp: 0.0,  name: "Richmond Acca Yard", lat: 37.5792, lon: -77.4795, limit: 15, signal: "CLEAR" },
      { mp: 4.8,  name: "James River Bridge", lat: 37.5198, lon: -77.4480, limit: 30, signal: "CLEAR" },
      { mp: 9.2,  name: "Bellwood Wye (Diverging East)", lat: 37.4601, lon: -77.4368, limit: 20, signal: "APPROACH", wye: true },
      { mp: 14.5, name: "Bermuda Hundred Junction", lat: 37.3580, lon: -77.3190, limit: 25, signal: "CLEAR" },
      { mp: 19.8, name: "Hopewell Chemical Yard", lat: 37.3045, lon: -77.2871, limit: 10, signal: "STOP" }
    ]
  },
  clifton_branch: {
    name: "Acca Wye to Rivanna / Clifton Forge Sub",
    waypoints: [
      { mp: 0.0,  name: "Richmond Acca Yard", lat: 37.5792, lon: -77.4795, limit: 15, signal: "CLEAR" },
      { mp: 1.4,  name: "Acca South Wye (West Leg)", lat: 37.5615, lon: -77.4712, limit: 20, signal: "APPROACH", wye: true },
      { mp: 6.2,  name: "Westham / James River Canal", lat: 37.5582, lon: -77.5491, limit: 35, signal: "CLEAR" },
      { mp: 18.0, name: "Sabot Siding", lat: 37.6015, lon: -77.7340, limit: 45, signal: "CLEAR" },
      { mp: 34.5, name: "Columbia / Rivanna Sub Milepost 34", lat: 37.7521, lon: -78.1620, limit: 45, signal: "CLEAR" }
    ]
  }
};
