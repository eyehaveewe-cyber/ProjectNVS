extends RefCounted
const Wildwood = preload("res://scripts/wildwood.gd")
## Native port of src/simulation.js. Lifesim-derived need rates and mood
## thresholds are preserved; music remains forgiving note-order matching. Saves also track woodland discoveries.
var definitions: Array = []
var player: Dictionary = {"x":0.0,"z":4.0,"yaw":0.0,"energy":1.0,"comfort":1.0,"frustration":0.0}
var healed: Array[String] = []
var sequence: Array[int] = []
var active_site: String = ""
var elapsed: float = 0.0
var resting: float = 0.0
var won: bool = false
var collected: Array[String] = []
var squirrel_stage: int = 0
var rain_learned: bool = false
var wildlife_healed: bool = false
var artemis_seen: bool = false
var nursery_watered: bool = false

func nearest(max_distance: float = 4.0) -> Dictionary:
	var best: Dictionary = {}
	var distance: float = max_distance
	for site in definitions:
		if healed.has(str(site.id)):
			continue
		var d: float = Vector2(float(player.x)-float(site.x),float(player.z)-float(site.z)).length()
		if d <= distance:
			distance = d
			best = site
	return best

func play_note(index: int) -> Dictionary:
	var site: Dictionary = nearest()
	if site.is_empty() or index < 0 or index > 4:
		sequence.clear()
		active_site = ""
		return {"type":"free"}
	resting = 0.0
	if active_site != str(site.id):
		sequence.clear()
		active_site = str(site.id)
	var expected: Array = site.sequence
	var correct: bool = index == int(expected[sequence.size()])
	var attempted: Array[int] = sequence.duplicate()
	attempted.append(index)
	sequence.clear()
	for size in range(mini(attempted.size(),expected.size()),0,-1):
		var matches: bool = true
		for i in size:
			if attempted[attempted.size()-size+i] != int(expected[i]):
				matches = false
				break
		if matches:
			for i in size:
				sequence.append(int(expected[i]))
			break
	if sequence.size() == expected.size():
		healed.append(str(site.id))
		player.energy = minf(1.0,float(player.energy)+float(site.reward))
		player.comfort = minf(1.0,float(player.comfort)+float(site.reward))
		player.frustration = maxf(0.0,float(player.frustration)-0.4)
		sequence.clear()
		active_site = ""
		return {"type":"healed","site":site}
	if not correct:
		player.frustration = minf(1.0,float(player.frustration)+0.03)
	return {"type":"progress" if correct else "wrong","site":site}

func tick(delta: float) -> bool:
	elapsed += delta
	player.energy = maxf(0.0,float(player.energy)-delta/900.0)
	player.comfort = maxf(0.0,float(player.comfort)-delta/750.0)
	player.frustration = maxf(0.0,float(player.frustration)-delta/100.0)
	if resting <= 0.0:
		return false
	if Vector2(float(player.x),float(player.z)-4.0).length() > 3.0:
		resting = 0.0
		return false
	resting = maxf(0.0,resting-delta)
	if resting <= 0.0:
		player.energy = minf(1.0,float(player.energy)+0.35)
		player.comfort = minf(1.0,float(player.comfort)+0.35)
		player.frustration = maxf(0.0,float(player.frustration)-0.4)
		return true
	return false

func start_rest() -> bool:
	if Vector2(float(player.x),float(player.z)-4.0).length() > 3.0:
		return false
	if resting <= 0.0:
		resting = 4.0
	sequence.clear()
	active_site = ""
	return true

func mood() -> String:
	if float(player.frustration) >= 0.55: return "Frustrated"
	if float(player.energy) <= 0.25: return "Tired"
	if float(player.comfort) <= 0.25: return "Uncomfortable"
	if float(player.energy) >= 0.7 and float(player.comfort) >= 0.7 and float(player.frustration) < 0.2: return "Happy"
	return "Content"

func serialize() -> Dictionary:
	return {"version":2,"player":player.duplicate(),"healed":healed.duplicate(),"elapsed":elapsed,"won":won,
		"collected":collected.duplicate(),"squirrel_stage":squirrel_stage,"rain_learned":rain_learned,
		"wildlife_healed":wildlife_healed,"artemis_seen":artemis_seen,"nursery_watered":nursery_watered}

func restore(value: Variant) -> void:
	if not value is Dictionary:
		return
	var record: Dictionary = value.get("player",{}) if value.get("player",{}) is Dictionary else {}
	for key in player:
		var item: Variant = record.get(key,player[key])
		if (item is int or item is float) and is_finite(float(item)):
			if key in ["energy","comfort","frustration"]:
				player[key] = clampf(float(item),0.0,1.0)
			elif key in ["x","z"]:
				player[key] = clampf(float(item),-Wildwood.BOUNDS,Wildwood.BOUNDS)
			else:
				player[key] = clampf(float(item),-10000.0,10000.0)
	if value.get("healed",[]) is Array:
		for id in value.get("healed",[]):
			for site in definitions:
				if id == site.id and not healed.has(str(id)):
					healed.append(str(id))
	var clock: Variant = value.get("elapsed",0.0)
	if (clock is int or clock is float) and is_finite(float(clock)):
		elapsed = clampf(float(clock),0.0,1000000000.0)
	won = value.get("won",false) == true and healed.size() == 9

	if value.get("collected",[]) is Array:
		for id in value.get("collected",[]):
			if id is String and id.begins_with("seed_") and id.substr(5).is_valid_int():
				var number: int = id.substr(5).to_int()
				if number >= 0 and number < Wildwood.COLLECTIBLE_POSITIONS.size() and id == "seed_%02d" % number and not collected.has(id):
					collected.append(id)
	var stage: Variant = value.get("squirrel_stage",0)
	if stage is int or stage is float:
		if is_finite(float(stage)): squirrel_stage = clampi(int(stage),0,5)
	for flag in ["rain_learned","wildlife_healed","artemis_seen","nursery_watered"]:
		set(flag,value.get(flag,false) == true)
