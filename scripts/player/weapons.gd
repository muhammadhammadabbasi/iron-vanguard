extends RefCounted
## Weapon definitions (IGI-style arsenal). Viewmodel positions are in "viewmodel units" (the viewmodel is
## rendered at 1/10 scale right in front of the camera so it never clips through walls).

const ORDER := ["knife", "m9", "m4", "ak", "svd"]

const DATA := {
	"knife": {"name": "COMBAT KNIFE", "slot": 1, "melee": true, "damage": 65.0, "range": 2.3, "rate": 0.55,
		"model": "knife", "sound": "knife_swing",
		"hip_pos": Vector3(0.17, -0.16, -0.34), "vm_rot": Vector3(0.35, 0.0, -0.25), "vm_offset": Vector3(0, 0, -0.06)},
	"m9": {"name": "M9 SILENCED", "slot": 2, "mag": 15, "start_reserve": 45, "max_reserve": 90, "damage": 40.0,
		"head": 100.0, "rate": 0.2, "auto": false, "hip": 0.016, "ads_spread": 0.003, "recoil": 0.018,
		"silenced": true, "sound": "pistol_silenced", "reload": 1.6, "ads_fov": 60.0, "model": "m9",
		"hip_pos": Vector3(0.15, -0.15, -0.34), "ads_pos": Vector3(0.0, -0.062, -0.30), "vm_offset": Vector3(0, 0, -0.04)},
	"m4": {"name": "M4A1", "slot": 3, "mag": 30, "start_reserve": 120, "max_reserve": 240, "damage": 31.0,
		"head": 100.0, "rate": 0.085, "auto": true, "hip": 0.024, "ads_spread": 0.0025, "recoil": 0.011,
		"silenced": false, "sound": "rifle_shot", "reload": 2.2, "ads_fov": 52.0, "model": "m4",
		"hip_pos": Vector3(0.17, -0.18, -0.36), "ads_pos": Vector3(0.0, -0.088, -0.28), "vm_offset": Vector3(0, 0, -0.14)},
	"ak": {"name": "AKM", "slot": 4, "mag": 30, "start_reserve": 90, "max_reserve": 240, "damage": 36.0,
		"head": 100.0, "rate": 0.1, "auto": true, "hip": 0.028, "ads_spread": 0.004, "recoil": 0.015,
		"silenced": false, "sound": "ak_shot", "reload": 2.4, "ads_fov": 54.0, "model": "ak",
		"hip_pos": Vector3(0.17, -0.18, -0.36), "ads_pos": Vector3(0.0, -0.075, -0.28), "vm_offset": Vector3(0, 0, -0.14)},
	"svd": {"name": "SVD DRAGUNOV", "slot": 5, "mag": 10, "start_reserve": 20, "max_reserve": 40, "damage": 130.0,
		"head": 300.0, "rate": 0.55, "auto": false, "hip": 0.05, "ads_spread": 0.0, "recoil": 0.045,
		"silenced": false, "sound": "sniper_shot", "reload": 2.8, "ads_fov": 11.0, "scope": true, "model": "svd",
		"hip_pos": Vector3(0.18, -0.18, -0.42), "ads_pos": Vector3(0.0, -0.1, -0.3), "vm_offset": Vector3(0, 0, -0.26)},
}


static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})
