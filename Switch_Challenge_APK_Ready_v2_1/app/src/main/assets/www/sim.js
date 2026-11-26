// Switch Challenge — Cab Rendering, Physics, Public Leaflet/OpenRailwayMap & Persistence
const SAVE_KEY = "switch_challenge_save_v2_1";

const state = {
  running: false,
  paused: false,
  loco: "wide_bnsf",
  orientation: "short", // LOCKED once trip starts
  route: "aline_main",
  role: "engineer",
  mp: 0.0,
  speed: 0.0,
  reverser: 0,
  throttle: 0,
  autoBrake: 0,
  indBrake: 45,
  brakePipe: 90,
  wyeAlignedMain: true,
  glanceOffset: 0,
  alerterTimer: 0,
  alerterActive: false,
  bellOn: false,
  weathering: "service",
  volume: 70,
  glanceSens: 2,
  trackOffset: 0
};

// ==========================================
// 1. DIRECT MAIN MENU SELECTION HANDLERS
// ==========================================
function selectOrientation(val) {
  state.orientation = val;
  document.getElementById("opt-orient-short").classList.toggle("active", val === "short");
  document.getElementById("opt-orient-long").classList.toggle("active", val === "long");
  document.getElementById("orient-desc").textContent = val === "long"
    ? "LONG HOOD FORWARD: Cab bulkhead blocks center view. Sightlines restricted to the rear cab door glass and the window behind the conductor."
    : "SHORT HOOD FORWARD: Standard forward cab view over the short nose with full front windshields.";
}

function selectRole(val) {
  state.role = val;
  document.getElementById("opt-role-engineer").classList.toggle("active", val === "engineer");
  document.getElementById("opt-role-conductor").classList.toggle("active", val === "conductor");
  document.getElementById("role-desc").textContent = val === "conductor"
    ? "CONDUCTOR SEAT (LEFT SIDE): Positioned on the left side of the cab with direct view out the left-side window."
    : "ENGINEER SEAT (RIGHT SIDE): Positioned at the AAR control stand on the right side of the cab.";
}

function onLocoChange(val) {
  state.loco = val;
  document.getElementById("loco-desc").textContent = val === "wide_bnsf"
    ? "Wide-body safety cab (BNSF 181 style): solid center electrical bulkhead; long-hood operation relies strictly on the rear door window and conductor window."
    : "Standard narrow-hood cab (DM&E 4006 SD40-2): dual narrow rear windows flanking the long hood plus side drop-sash windows.";
}

function onRouteChange(val) {
  state.route = val;
}

function checkSavedGame() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    const btn = document.getElementById("btn-resume-save");
    if (raw) {
      const data = JSON.parse(raw);
      btn.disabled = false;
      btn.textContent = `RESUME SAVED TRIP (${data.route.toUpperCase()} @ MP ${Number(data.mp).toFixed(1)} — ${data.orientation.toUpperCase()} HOOD)`;
    } else {
      btn.disabled = true;
      btn.textContent = "RESUME SAVED TRIP (NO SAVE FOUND)";
    }
  } catch (err) {
    console.warn("Storage check skipped:", err);
  }
}

function startNewTrip() {
  state.loco = document.getElementById("sel-loco").value;
  state.route = document.getElementById("sel-route").value;
  state.mp = 0.0;
  state.speed = 0.0;
  state.throttle = 0;
  state.reverser = 0;
  state.autoBrake = 0;
  state.indBrake = 45;
  state.glanceOffset = 0;
  launchSimulation();
}

function resumeSavedTrip() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return;
    Object.assign(state, JSON.parse(raw));
    launchSimulation();
  } catch (err) {
    console.error("Failed to load save:", err);
  }
}

// ==========================================
// 2. AUDIO ENGINE (SAFE NON-BLOCKING INIT)
// ==========================================
let audioCtx = null, engineOsc = null, engineGain = null;
function initAudio() {
  try {
    if (audioCtx) return;
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    audioCtx = new AudioContextClass();
    engineOsc = audioCtx.createOscillator();
    engineGain = audioCtx.createGain();
    engineOsc.type = "sawtooth";
    engineOsc.frequency.value = 34;
    engineGain.gain.value = 0.03;
    const filter = audioCtx.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = 110;
    engineOsc.connect(filter);
    filter.connect(engineGain);
    engineGain.connect(audioCtx.destination);
    engineOsc.start();
  } catch (e) {
    console.warn("Audio init deferred:", e);
  }
}

function playHorn() {
  initAudio();
  if (!audioCtx) return;
  try {
    const vol = (state.volume / 100) * 0.14;
    [311.13, 369.99, 466.16].forEach(freq => {
      const osc = audioCtx.createOscillator();
      const g = audioCtx.createGain();
      osc.type = "sawtooth";
      osc.frequency.value = freq;
      g.gain.setValueAtTime(vol, audioCtx.currentTime);
      g.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.85);
      osc.connect(g); g.connect(audioCtx.destination);
      osc.start(); osc.stop(audioCtx.currentTime + 0.85);
    });
  } catch (e) {}
}

// ==========================================
// 3. LIVE PUBLIC LEAFLET + OPENRAILWAYMAP
// ==========================================
let leafletMap = null, corridorPolyline = null, trainMarker = null;

function initPublicRailMap() {
  const mapEl = document.getElementById("leaflet-map");
  if (typeof L === "undefined") {
    document.getElementById("map-source-lbl").textContent = "Offline Vector GIS Mode";
    return;
  }
  if (!leafletMap) {
    leafletMap = L.map("leaflet-map", {
      center: [37.5792, -77.4795],
      zoom: 13,
      zoomControl: true,
      attributionControl: false
    });

    // Base Public Map: CartoDB Dark Matter (OpenStreetMap public data)
    L.tileLayer("https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png", {
      maxZoom: 18,
      subdomains: "abcd"
    }).addTo(leafletMap);

    // Public Railroad Infrastructure Layer: OpenRailwayMap
    L.tileLayer("https://{s}.tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png", {
      maxZoom: 18,
      opacity: 0.85
    }).addTo(leafletMap);
  }

  // Draw active route corridor polyline
  const wps = GIS_CORRIDORS[state.route].waypoints;
  const latlngs = wps.map(w => [w.lat, w.lon]);

  if (corridorPolyline) leafletMap.removeLayer(corridorPolyline);
  corridorPolyline = L.polyline(latlngs, { color: "#06b6d4", weight: 3, dashArray: "6, 4" }).addTo(leafletMap);

  if (trainMarker) leafletMap.removeLayer(trainMarker);
  trainMarker = L.circleMarker(latlngs[0], {
    radius: 7, fillColor: "#10b981", color: "#ffffff", weight: 2, fillOpacity: 1
  }).addTo(leafletMap);

  setTimeout(() => {
    leafletMap.invalidateSize();
    leafletMap.setView(latlngs[0], 13);
  }, 100);
}

// ==========================================
// 4. LAUNCH, PAUSE & SAVE/QUIT
// ==========================================
function launchSimulation() {
  document.getElementById("main-menu").style.display = "none";
  document.getElementById("pause-modal").style.display = "none";
  state.running = true;
  state.paused = false;

  initAudio();
  initPublicRailMap();

  // Lock orientation in HUD and Pause Menu
  const orientLabel = state.orientation === "long" ? "LONG HOOD (LOCKED)" : "SHORT HOOD (LOCKED)";
  document.getElementById("hud-orient").textContent = orientLabel;
  document.getElementById("pause-orient-lock").textContent = "LOCKED: " + state.orientation.toUpperCase() + " HOOD";
  document.getElementById("hud-role").textContent = state.role.toUpperCase();
  document.getElementById("hud-sub").textContent = GIS_CORRIDORS[state.route].name.split("(")[0].trim().toUpperCase();

  // Sync control positions
  document.getElementById("rng-throttle").value = state.throttle;
  document.getElementById("lbl-notch").textContent = state.throttle === 0 ? "IDLE" : "N" + state.throttle;
  document.getElementById("rng-auto").value = state.autoBrake;
  document.getElementById("lbl-auto").textContent = state.autoBrake === 0 ? "REL" : state.autoBrake + "%";
  document.getElementById("rng-ind").value = state.indBrake;
  document.getElementById("lbl-ind").textContent = state.indBrake + "%";
  setReverser(state.reverser);

  document.getElementById("set-weathering").value = state.weathering;
  document.getElementById("set-vol").value = state.volume;
  document.getElementById("set-glance").value = state.glanceSens;
}

function togglePause(forceState) {
  if (!state.running) return;
  state.paused = typeof forceState === "boolean" ? forceState : !state.paused;
  document.getElementById("pause-modal").style.display = state.paused ? "flex" : "none";
  document.getElementById("save-toast").textContent = "";
}

function saveProgress() {
  const payload = {
    loco: state.loco,
    orientation: state.orientation,
    route: state.route,
    role: state.role,
    mp: state.mp,
    speed: state.speed,
    reverser: state.reverser,
    throttle: state.throttle,
    autoBrake: state.autoBrake,
    indBrake: state.indBrake,
    brakePipe: state.brakePipe,
    wyeAlignedMain: state.wyeAlignedMain,
    weathering: state.weathering,
    volume: state.volume,
    glanceSens: state.glanceSens
  };
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(payload));
    document.getElementById("save-toast").textContent = `Trip saved at MP ${state.mp.toFixed(2)} (${new Date().toLocaleTimeString()}).`;
    checkSavedGame();
  } catch (e) {
    document.getElementById("save-toast").textContent = "Save completed in session.";
  }
}

function saveAndQuit() {
  saveProgress();
  state.running = false;
  state.paused = false;
  document.getElementById("pause-modal").style.display = "none";
  document.getElementById("main-menu").style.display = "flex";
}

// ==========================================
// 5. CAB CONTROLS
// ==========================================
function onThrottleInput(val) {
  state.throttle = Number(val);
  document.getElementById("lbl-notch").textContent = state.throttle === 0 ? "IDLE" : "N" + state.throttle;
  resetAlerter();
}

function onAutoBrakeInput(val) {
  state.autoBrake = Number(val);
  document.getElementById("lbl-auto").textContent = state.autoBrake === 0 ? "REL" : state.autoBrake + "%";
  resetAlerter();
}

function onIndBrakeInput(val) {
  state.indBrake = Number(val);
  document.getElementById("lbl-ind").textContent = state.indBrake + "%";
  resetAlerter();
}

function setReverser(dir) {
  state.reverser = dir;
  ["rev-f", "rev-n", "rev-r"].forEach(id => document.getElementById(id).style.borderColor = "#2a313c");
  const activeId = dir === 1 ? "rev-f" : dir === -1 ? "rev-r" : "rev-n";
  document.getElementById(activeId).style.borderColor = "var(--amber)";
}

function toggleBell() {
  state.bellOn = !state.bellOn;
  document.getElementById("btn-bell").style.borderColor = state.bellOn ? "var(--amber)" : "#2a313c";
}

function toggleWyeSwitch() {
  state.wyeAlignedMain = !state.wyeAlignedMain;
  document.getElementById("wye-status").textContent = "Wye Switch: " + (state.wyeAlignedMain ? "MAIN" : "DIVERGING");
}

function cycleGlance() {
  state.glanceOffset = state.glanceOffset === 0 ? -1 : state.glanceOffset === -1 ? 1 : 0;
}

function resetAlerter() {
  state.alerterTimer = 0;
  state.alerterActive = false;
  document.getElementById("alerter-banner").style.display = "none";
}
function ackAlerter() { resetAlerter(); }

window.addEventListener("keydown", e => {
  if (e.key === "Escape") togglePause();
  if (!state.running || state.paused) return;
  if (e.code === "Space") { e.preventDefault(); ackAlerter(); }
  if (e.key.toLowerCase() === "h") playHorn();
  if (e.key.toLowerCase() === "g") toggleWyeSwitch();
  if (e.key.toLowerCase() === "q") state.glanceOffset = Math.max(-1, state.glanceOffset - 1);
  if (e.key.toLowerCase() === "e") state.glanceOffset = Math.min(1, state.glanceOffset + 1);
});

// ==========================================
// 6. PHYSICS & GIS INTERPOLATION
// ==========================================
function getCorridorStatus() {
  const wps = GIS_CORRIDORS[state.route].waypoints;
  let current = wps[0], next = wps[wps.length - 1];
  for (let i = 0; i < wps.length - 1; i++) {
    if (state.mp >= wps[i].mp && state.mp <= wps[i+1].mp) {
      current = wps[i];
      next = wps[i+1];
      break;
    }
  }
  const segLen = Math.max(0.01, next.mp - current.mp);
  const t = Math.min(1, Math.max(0, (state.mp - current.mp) / segLen));
  const lat = current.lat + (next.lat - current.lat) * t;
  const lon = current.lon + (next.lon - current.lon) * t;
  return { current, next, lat, lon, distToNext: Math.max(0, next.mp - state.mp) };
}

function updatePhysics(dt) {
  if (!state.running || state.paused) return;

  const tractive = state.reverser * state.throttle * 2.4;
  const brakeForce = (state.autoBrake * 0.16) + (state.indBrake * 0.09) + 0.18;
  let accel = tractive;
  if (state.speed > 0.05) accel -= brakeForce;
  else if (state.speed < -0.05) accel += brakeForce;
  else if (Math.abs(tractive) <= brakeForce) { state.speed = 0; accel = 0; }

  state.speed = Math.max(-25, Math.min(70, state.speed + accel * dt));
  state.mp = Math.max(0, state.mp + (state.speed / 3600) * dt);
  state.trackOffset += state.speed * dt * 18;
  state.brakePipe = Math.round(90 - (state.autoBrake * 0.26));

  if (Math.abs(state.speed) > 2) {
    state.alerterTimer += dt;
    if (state.alerterTimer > 22) {
      state.alerterActive = true;
      document.getElementById("alerter-banner").style.display = "block";
    }
    if (state.alerterTimer > 30) {
      state.autoBrake = 100;
      document.getElementById("rng-auto").value = 100;
      document.getElementById("lbl-auto").textContent = "PENALTY";
    }
  }

  if (engineOsc && audioCtx) {
    try {
      engineOsc.frequency.setTargetAtTime(34 + state.throttle * 7.5, audioCtx.currentTime, 0.1);
      engineGain.gain.setTargetAtTime((state.volume / 100) * 0.07, audioCtx.currentTime, 0.1);
    } catch (e) {}
  }

  const gis = getCorridorStatus();
  document.getElementById("hud-mp").textContent = "MP " + state.mp.toFixed(2);
  document.getElementById("hud-next").textContent = `${gis.next.name.toUpperCase()} (${gis.distToNext.toFixed(1)} MI)`;
  document.getElementById("val-speed").textContent = Math.abs(state.speed).toFixed(1);
  document.getElementById("val-limit").textContent = gis.current.limit;
  document.getElementById("val-bp").textContent = state.brakePipe;
  document.getElementById("geo-coords").textContent = `${gis.lat.toFixed(4)}°N, ${Math.abs(gis.lon).toFixed(4)}°W`;

  const sigEl = document.getElementById("ptc-signal");
  sigEl.textContent = gis.current.signal;
  sigEl.style.color = gis.current.signal === "CLEAR" ? "#10b981" : gis.current.signal === "APPROACH" ? "#f59e0b" : "#ef4444";

  // Update live marker on Leaflet / OpenRailwayMap
  if (leafletMap && trainMarker) {
    trainMarker.setLatLng([gis.lat, gis.lon]);
    if (Math.abs(state.speed) > 0.2) {
      leafletMap.panTo([gis.lat, gis.lon], { animate: false });
    }
  }
}

// ==========================================
// 7. REALISTIC CAB & SIGHTLINE RENDERER
// ==========================================
const cabCanvas = document.getElementById("cabCanvas");
const ctx = cabCanvas.getContext("2d");

function drawOutsideWorld(x, y, w, h, perspectiveShift) {
  ctx.save();
  ctx.beginPath();
  ctx.rect(x, y, w, h);
  ctx.clip();

  const sky = ctx.createLinearGradient(0, y, 0, y + h * 0.55);
  sky.addColorStop(0, "#6b8fb3");
  sky.addColorStop(1, "#cbd5e1");
  ctx.fillStyle = sky;
  ctx.fillRect(x, y, w, h * 0.55);

  const horizonY = y + h * 0.52;
  ctx.fillStyle = "#3f523a";
  ctx.fillRect(x, horizonY - 26, w, 28);

  ctx.fillStyle = "#524c46";
  ctx.fillRect(x, horizonY, w, h - (horizonY - y));

  const vanishX = x + w * 0.5 + perspectiveShift;
  const bottomCenter = x + w * 0.5 + perspectiveShift * 0.3;

  ctx.strokeStyle = "#2b231d";
  for (let i = 1; i <= 18; i++) {
    const p = ((i * 35 + (state.trackOffset % 35)) / 630);
    const ty = horizonY + Math.pow(p, 1.7) * (y + h - horizonY);
    const halfSpan = 8 + Math.pow(p, 1.6) * (w * 0.42);
    const cx = vanishX + (bottomCenter - vanishX) * p;
    ctx.lineWidth = 1 + p * 5;
    ctx.beginPath();
    ctx.moveTo(cx - halfSpan, ty);
    ctx.lineTo(cx + halfSpan, ty);
    ctx.stroke();
  }

  ctx.strokeStyle = "#94a3b8";
  ctx.lineWidth = 3;
  [-1, 1].forEach(side => {
    ctx.beginPath();
    ctx.moveTo(vanishX + side * 4, horizonY);
    ctx.lineTo(bottomCenter + side * (w * 0.28), y + h);
    ctx.stroke();
  });

  ctx.restore();
}

function drawCabInterior() {
  if (cabCanvas.clientWidth === 0 || cabCanvas.clientHeight === 0) return;
  cabCanvas.width = cabCanvas.clientWidth;
  cabCanvas.height = cabCanvas.clientHeight;
  const W = cabCanvas.width, H = cabCanvas.height;
  const roleShift = state.role === "conductor" ? 75 : 0;
  const shift = state.glanceOffset * (35 * state.glanceSens) + roleShift;

  const wallBase = state.weathering === "heavy" ? "#5a564c" : state.weathering === "clean" ? "#7a868c" : "#67706e";
  ctx.fillStyle = wallBase;
  ctx.fillRect(0, 0, W, H);

  if (state.orientation === "long" && state.loco === "wide_bnsf") {
    // WIDE-BODY LONG HOOD FORWARD:
    // ONLY two sightlines exist:
    // 1) Window behind the conductor (left)
    // 2) Window out the rear cab door (right, beside long hood walkway & yellow handrail)

    const condWin = { x: W * 0.04 + shift * 0.4, y: H * 0.16, w: W * 0.25, h: H * 0.35 };
    drawOutsideWorld(condWin.x, condWin.y, condWin.w, condWin.h, -60);
    ctx.strokeStyle = "#1e242b"; ctx.lineWidth = 8;
    ctx.strokeRect(condWin.x, condWin.y, condWin.w, condWin.h);
    ctx.beginPath(); ctx.moveTo(condWin.x + condWin.w/2, condWin.y); ctx.lineTo(condWin.x + condWin.w/2, condWin.y + condWin.h); ctx.stroke();

    const doorWin = { x: W * 0.72 + shift * 0.4, y: H * 0.14, w: W * 0.17, h: H * 0.44 };
    drawOutsideWorld(doorWin.x, doorWin.y, doorWin.w, doorWin.h, 35);

    ctx.save();
    ctx.beginPath(); ctx.rect(doorWin.x, doorWin.y, doorWin.w, doorWin.h); ctx.clip();
    ctx.fillStyle = "#1e3a5f";
    ctx.fillRect(doorWin.x, doorWin.y, doorWin.w * 0.36, doorWin.h);
    ctx.fillStyle = "#eab308";
    ctx.fillRect(doorWin.x, doorWin.y + doorWin.h * 0.55, doorWin.w * 0.36, doorWin.h * 0.16);
    ctx.strokeStyle = "#facc15"; ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(doorWin.x + doorWin.w * 0.36, doorWin.y + doorWin.h * 0.62);
    ctx.lineTo(doorWin.x + doorWin.w * 0.78, doorWin.y + doorWin.h * 0.68);
    ctx.lineTo(doorWin.x + doorWin.w * 0.78, doorWin.y + doorWin.h);
    ctx.stroke();
    ctx.restore();

    ctx.strokeStyle = "#11151a"; ctx.lineWidth = 10;
    ctx.strokeRect(doorWin.x, doorWin.y, doorWin.w, doorWin.h);

    // Solid Center Bulkhead & High-Voltage Cabinets
    const bhX = W * 0.32 + shift * 0.4, bhW = W * 0.37;
    ctx.fillStyle = "#5c6463";
    ctx.fillRect(bhX, H * 0.05, bhW, H * 0.85);
    ctx.strokeStyle = "#2b3033"; ctx.lineWidth = 3;
    ctx.strokeRect(bhX + 10, H * 0.12, bhW * 0.45, H * 0.42);
    ctx.strokeRect(bhX + 10 + bhW * 0.48, H * 0.12, bhW * 0.45, H * 0.42);

    ctx.fillStyle = "#b91c1c";
    ctx.fillRect(bhX + 20, H * 0.16, 48, 16);
    ctx.fillRect(bhX + bhW * 0.55, H * 0.16, 48, 16);
    ctx.fillStyle = "#fff"; ctx.font = "bold 8px sans-serif";
    ctx.fillText("HIGH VOLT", bhX + 23, H * 0.173);
    ctx.fillText("HIGH VOLT", bhX + bhW * 0.55 + 3, H * 0.173);

  } else if (state.orientation === "long") {
    // STANDARD CAB (SD40-2) LONG HOOD FORWARD
    const hoodX = W * 0.36 + shift * 0.4, hoodW = W * 0.28;
    const leftWin = { x: W * 0.14 + shift * 0.4, y: H * 0.14, w: W * 0.18, h: H * 0.42 };
    const rightWin = { x: W * 0.68 + shift * 0.4, y: H * 0.14, w: W * 0.18, h: H * 0.42 };
    drawOutsideWorld(leftWin.x, leftWin.y, leftWin.w, leftWin.h, -30);
    drawOutsideWorld(rightWin.x, rightWin.y, rightWin.w, rightWin.h, 30);
    ctx.strokeStyle = "#14181d"; ctx.lineWidth = 9;
    ctx.strokeRect(leftWin.x, leftWin.y, leftWin.w, leftWin.h);
    ctx.strokeRect(rightWin.x, rightWin.y, rightWin.w, rightWin.h);

    ctx.fillStyle = "#565e5d";
    ctx.fillRect(hoodX, H * 0.08, hoodW, H * 0.8);
  } else {
    // SHORT HOOD FORWARD
    const winY = H * 0.10, winH = H * 0.42;
    drawOutsideWorld(W * 0.06, winY, W * 0.88, winH, shift * 0.5);

    const noseTop = winY + winH * 0.58;
    ctx.fillStyle = state.loco === "wide_bnsf" ? "#eab308" : "#1d4ed8";
    ctx.beginPath();
    ctx.moveTo(W * 0.22 + shift * 0.3, winY + winH);
    ctx.lineTo(W * 0.34 + shift * 0.3, noseTop);
    ctx.lineTo(W * 0.66 + shift * 0.3, noseTop);
    ctx.lineTo(W * 0.78 + shift * 0.3, winY + winH);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = wallBase;
    ctx.fillRect(W * 0.485 + shift * 0.3, winY, W * 0.03, winH);
    ctx.fillRect(W * 0.22 + shift * 0.3, winY, W * 0.025, winH);
    ctx.fillRect(W * 0.755 + shift * 0.3, winY, W * 0.025, winH);
    ctx.strokeStyle = "#181c20"; ctx.lineWidth = 8;
    ctx.strokeRect(W * 0.06, winY, W * 0.88, winH);
  }

  if (state.weathering === "heavy") {
    ctx.fillStyle = "rgba(110, 62, 28, 0.22)";
    ctx.fillRect(0, 0, W, H);
  }

  // AAR Control Stand in Foreground (shifts right when seated as Conductor)
  const standX = state.role === "conductor" ? W * 0.68 : W * 0.38;
  ctx.fillStyle = "#1e2228";
  ctx.fillRect(standX, H * 0.56, 200, H * 0.44);
  ctx.strokeStyle = "#374151"; ctx.lineWidth = 3;
  ctx.strokeRect(standX, H * 0.56, 200, H * 0.44);

  ctx.fillStyle = "#2b303a";
  ctx.fillRect(standX + 120, H * 0.47, 56, 50);
  ctx.fillStyle = "#f8fafc";
  ctx.beginPath(); ctx.arc(standX + 148, H * 0.47 + 25, 17, 0, Math.PI * 2); ctx.fill();
  const angle = Math.PI * 0.75 + (Math.abs(state.speed) / 70) * Math.PI * 1.5;
  ctx.strokeStyle = "#dc2626"; ctx.lineWidth = 2.5;
  ctx.beginPath();
  ctx.moveTo(standX + 148, H * 0.47 + 25);
  ctx.lineTo(standX + 148 + Math.cos(angle) * 13, H * 0.47 + 25 + Math.sin(angle) * 13);
  ctx.stroke();

  ctx.fillStyle = "#dc2626";
  ctx.fillRect(standX + 24, H * 0.68, 46, 10);
  ctx.fillStyle = "#94a3b8";
  ctx.fillRect(standX + 24, H * 0.78, 52, 9);
}

checkSavedGame();

let lastTime = performance.now();
function loop(now) {
  const dt = Math.min(0.1, (now - lastTime) / 1000);
  lastTime = now;
  updatePhysics(dt);
  drawCabInterior();
  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);
