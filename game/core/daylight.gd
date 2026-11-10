class_name Daylight
extends RefCounted
## Day and night follow Changsha time and the real sun over Changsha. Same calculation as public/house-v2/lighting.mjs in VADS.
##
## DATA: reading(now_ms) answers hour, darkness, phase ("night", "dawn", "dusk", "day"), elevation, azimuth, shift, length,
##   tint and beam (colours as [r, g, b], 0 to 255), tintAlpha, beamAlpha. A test compares it with the VADS code across a year.

const LAT := 28.2282
const LON := 112.9388
const SHANGHAI_MS := 28800000.0
const SKY := {
	"night": [[37, 50, 78], [54, 71, 102], [79, 97, 120]],
	"blue": [[70, 86, 140], [150, 140, 180], [90, 96, 130]],
	"dawn": [[196, 171, 179], [238, 208, 172], [155, 156, 167]],
	"dusk": [[161, 147, 179], [226, 185, 174], [119, 127, 157]],
	"day": [[139, 189, 210], [184, 213, 223], [125, 155, 164]],
}


## Rounds like Math.round in JavaScript, which matters for negative halves.
static func js_round(v: float) -> float:
	return floorf(v + 0.5)


static func local_hour(now_ms: float) -> float:
	var d := Time.get_datetime_dict_from_unix_time(int(floorf((now_ms + SHANGHAI_MS) / 1000.0)))
	return float(d["hour"]) + float(d["minute"]) / 60.0


static func sun_position(now_ms: float) -> Dictionary:
	var d := Time.get_datetime_dict_from_unix_time(int(floorf(now_ms / 1000.0)))
	var start := float(Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})) * 1000.0
	var doy := (now_ms - start) / 86400000.0
	var g := TAU / 365.0 * (doy - 1.0 + (float(d["hour"]) - 12.0) / 24.0)
	var eq := 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2.0 * g) - 0.040849 * sin(2.0 * g))
	var decl := 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2.0 * g) + 0.000907 * sin(2.0 * g) - 0.002697 * cos(3.0 * g) + 0.00148 * sin(3.0 * g)
	var minutes := float(d["hour"]) * 60.0 + float(d["minute"]) + float(d["second"]) / 60.0
	var solar := minutes + eq + 4.0 * LON
	var ha := deg_to_rad(solar / 4.0 - 180.0)
	var la := deg_to_rad(LAT)
	var cos_z := sin(la) * sin(decl) + cos(la) * cos(decl) * cos(ha)
	var zen := acos(clampf(cos_z, -1.0, 1.0))
	var az := fposmod(rad_to_deg(atan2(sin(ha), cos(ha) * sin(la) - tan(decl) * cos(la))) + 180.0 + 360.0, 360.0)
	return {"elevation": 90.0 - rad_to_deg(zen), "azimuth": az}


static func darkness_for(e: float) -> float:
	if e >= 8.0:
		return 0.03
	if e >= -6.0:
		return 0.03 + (8.0 - e) / 14.0 * 0.37
	return 0.4 + minf(0.12, (-6.0 - e) / 6.0 * 0.12)


static func light_enabled(mode: String, darkness: float) -> bool:
	return mode == "on" or (mode != "off" and darkness > 0.15)


static func _ambient(e: float, morning: bool) -> Dictionary:
	if e >= 14.0:
		return {"tint": [255, 248, 232], "tintAlpha": 0.0, "beam": [255, 242, 196], "beamAlpha": 0.17}
	if e >= 2.0:
		var t := (14.0 - e) / 12.0
		return {"tint": [255, 214, 196] if morning else [255, 190, 120], "tintAlpha": 0.12 * t, "beam": [255, 226, 196] if morning else [255, 200, 128], "beamAlpha": 0.17 + 0.05 * t}
	if e >= -6.0:
		var t := (2.0 - e) / 8.0
		return {"tint": [150, 130, 190] if morning else [120, 110, 190], "tintAlpha": 0.11, "beam": [255, 170, 140], "beamAlpha": 0.12 * (1.0 - t)}
	return {"tint": [17, 26, 54], "tintAlpha": 0.0, "beam": [200, 210, 255], "beamAlpha": 0.0}


static func reading(now_ms: float) -> Dictionary:
	var hour := local_hour(now_ms)
	var sun := sun_position(now_ms)
	var e: float = sun["elevation"]
	var morning := hour < 12.0
	var phase := "night" if e < -6.0 else (("dawn" if morning else "dusk") if e < 8.0 else "day")
	var out := {"hour": hour, "darkness": darkness_for(e), "phase": phase, "elevation": js_round(e * 10.0) / 10.0, "azimuth": js_round(sun["azimuth"]), "shift": clampf((180.0 - float(sun["azimuth"])) * 1.2, -110.0, 110.0), "length": js_round(clampf(100.0 + (60.0 - maxf(0.0, e)) * 2.6, 100.0, 255.0))}
	out.merge(_ambient(e, morning))
	return out


static func _mixc(a: Array, b: Array, t: float) -> Array:
	return [lerpf(a[0], b[0], t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t)]


## Three colours for the view out of the window: sky, low sky, hills.
static func sky(light: Dictionary) -> Array:
	var e: float = light["elevation"]
	var warm: Array = SKY["dawn"] if light["phase"] == "dawn" else SKY["dusk"]
	var out: Array = []
	for i in 3:
		if e >= 14.0:
			out.append(SKY["day"][i])
		elif e >= 2.0:
			out.append(_mixc(warm[i], SKY["day"][i], (e - 2.0) / 12.0))
		elif e >= -6.0:
			out.append(_mixc(SKY["blue"][i], warm[i], (e + 6.0) / 8.0))
		else:
			out.append(_mixc(SKY["blue"][i], SKY["night"][i], clampf((-6.0 - e) / 6.0, 0.0, 1.0)))
	return out
