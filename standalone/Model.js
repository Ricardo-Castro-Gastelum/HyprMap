// Model.js — HyprMap data model.
// Reads `hyprctl -j clients`, groups by workspace, and normalizes each
// window's geometry to fractions of the workspace bounding box.

.pragma library

// Map of window classes whose icon name differs from the class itself.
var FALLBACK_ICONS = {
  "kitty": "kitty",
  "alacritty": "Alacritty",
  "foot": "foot",
  "ghostty": "com.mitchellh.ghostty",
  "wezterm": "org.wezfurlong.wezterm",
  "org.alacritty": "Alacritty",
  "google-chrome": "google-chrome",
  "google-chrome-stable": "google-chrome",
  "chrome": "google-chrome",
  "chromium": "chromium",
  "brave": "brave-browser",
  "brave-browser": "brave-browser",
  "microsoft-edge": "microsoft-edge",
  "firefox": "firefox",
  "zen": "zen",
  "code": "com.visualstudio.code",
  "vscode": "com.visualstudio.code",
  "nautilus": "org.gnome.Nautilus",
  "files": "org.gnome.Nautilus",
  "dolphin": "org.kde.dolphin",
  "thunar": "org.xfce.thunar",
  "gedit": "org.gnome.gedit",
  "texteditors": "org.gnome.TextEditor",
  "telegram": "telegram",
  "telegramdesktop": "telegram",
  "discord": "discord",
  "obsidian": "obsidian",
  "spotify": "spotify",
  "x": "twitter-x",
  "x.com": "twitter-x",
  "twitter": "twitter-x",
  "whatsapp": "whatsapp",
  "web.whatsapp.com": "whatsapp",
  "zoom": "zoom",
  "slack": "slack",
  "notion": "notion",
  "cursor": "cursor",
  "thunderbird": "thunderbird",
  "org.gnome.Tablet": "org.gnome.Tablet",
  "com.obsproject.studio": "com.obsproject.studio",
  "vlc": "vlc",
  "mpv": "mpv",
  "io.miriani.Mespel": "io.miriani.Mespel",
  "cellular automata": "cellular-automata"
}

var GENERIC_ICON = "application-x-executable"

// Lowercase + normalize a class into a best-effort icon theme name.
var _iconCache = {}

function __normalize(raw) {
  return String(raw || "").toLowerCase().trim()
    .replace(/\.desktop$/, "")
    .replace(/\s+/g, "-")
}

function iconNameFor(appClass) {
  if (!appClass) return GENERIC_ICON
  var key = __normalize(appClass)
  if (key.length === 0) return GENERIC_ICON
  if (_iconCache[key]) return _iconCache[key]

  var mapped = FALLBACK_ICONS[key]
  if (mapped) {
    _iconCache[key] = mapped
    return mapped
  }

  _iconCache[key] = key
  return key
}

function __isMappedWindow(client) {
  if (!client) return false
  if (client.mapped !== true) return false
  if (client.hidden === true) return false
  if (client.workspace && client.workspace.id !== undefined) {
    // Ignore scratchpad (negative id) and windows without a workspace.
    return client.workspace.id > 0
  }
  return true
}

function computeRows(clientsJson, focusedWorkspaceId) {
  var rows = []
  if (!clientsJson) return rows

  var parsed = null
  try {
    parsed = JSON.parse(clientsJson)
  } catch (e) {
    return rows
  }
  if (!Array.isArray(parsed)) return rows

  var byWorkspace = {}

  for (var i = 0; i < parsed.length; i++) {
    var client = parsed[i]
    if (!__isMappedWindow(client)) continue

    var wsId = client.workspace.id
    if (!byWorkspace[wsId]) byWorkspace[wsId] = []
    byWorkspace[wsId].push(client)
  }

  var ids = Object.keys(byWorkspace)
  ids.sort(function(a, b) { return parseInt(a, 10) - parseInt(b, 10) })

  for (var j = 0; j < ids.length; j++) {
    var id = parseInt(ids[j], 10)
    var windows = byWorkspace[id]

    // Bounding box that covers every window of this workspace.
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    for (var w = 0; w < windows.length; w++) {
      var c = windows[w]
      var at = c.at || [0, 0]
      var size = c.size || [0, 0]
      var x = at[0], y = at[1]
      var x2 = x + size[0], y2 = y + size[1]
      if (x < minX) minX = x
      if (y < minY) minY = y
      if (x2 > maxX) maxX = x2
      if (y2 > maxY) maxY = y2
    }

    var ww = maxX - minX
    var wh = maxY - minY
    if (ww <= 0) ww = 1
    if (wh <= 0) wh = 1

    var winRows = []
    for (var v = 0; v < windows.length; v++) {
      var cl = windows[v]
      var cAt = cl.at || [0, 0]
      var cSize = cl.size || [0, 0]
      var frac = {
        cx: (cAt[0] - minX) / ww,
        cy: (cAt[1] - minY) / wh,
        cw: cSize[0] / ww,
        ch: cSize[1] / wh
      }
      winRows.push({
        icon: iconNameFor(cl.class || cl.initialClass || cl.title || ""),
        floating: cl.floating === true,
        fullscreen: (cl.fullscreen || 0) > 0,
        cx: frac.cx, cy: frac.cy, cw: frac.cw, ch: frac.ch
      })
    }

    rows.push({
      id: id,
      active: id === focusedWorkspaceId,
      windows: winRows
    })
  }

  return rows
}