extends Node3D

const CaseFile = preload("res://frontier_case.gd")
const Sites = preload("res://frontier_sites.gd")
const Guardian = preload("res://frontier_guardian.gd")
const FloodGauge = preload("res://frontier_incident.gd")
const Station = preload("res://frontier_station.gd")
const Windgate = preload("res://frontier_disappearance.gd")
const Interface = preload("res://frontier_ui.gd")
const Soundscape = preload("res://frontier_audio.gd")
const AIRCRAFT = preload("res://aircraft.tscn")
const SAVE_FILE := "user://dark_frontier.cfg"
const INTERACT_RANGE := 2.65
const CACHE_ORDER := ["rune_moon", "rune_sun", "rune_current"]
const RELAY_ORDER := ["anchor_east", "anchor_west", "anchor_core"]
const RELAY_TIME := 26.0
const CHAPTERS := [
	"I   The Lost Expedition", "II   The Three Seals", "III   Windgate Mysteries",
	"IV   The Hanging Court", "V   The Final Spire",
]
const ACTIONS := {
	"weather_door": "Operate the weather station door",
	"bunk_door": "Operate the bunkhouse door",
	"relay_door": "Operate the pump house door",
	"store_door": "Operate the stores door",
	"camp_rest": "Rest at the expedition fire",
	"tunnel_rest": "Rest at the shelter brazier",
	"airstrip_rest": "Rest at the runway shelter",
	"spire_start": "Open Mara's channel and start the relay",
	"anchor_east": "Ground the east anchor",
	"anchor_west": "Ground the west anchor",
	"anchor_core": "Ground the core anchor",
	"publish": "Restore the Spires",
	"rescue": "Safely disable the Spires",
	"rune_current": "Turn the current rune",
	"rune_moon": "Turn the crescent rune",
	"rune_sun": "Turn the sun rune",
}

var game
var valley
var pilot
var ui = Interface.new()
var audio = Soundscape.new()
var sites = Sites.new()
var station := Station.new()
var windgate := Windgate.new()
var guardian = Guardian.new()
var incident := FloodGauge.new()
var case_file = CaseFile.new()
var aircraft
var running := false
var health := 100.0
var exposure := 0.0
var supplies := 1
var flares := 0
var save_path := SAVE_FILE
var persistence_enabled := true
var landed_observatory := false
var cache_open := false
var cache_steps := 0
var report_timer := 0.0
var sunrise := 0.0
var flare: OmniLight3D
var flare_clock := 0.0
var ending_rays: MeshInstance3D
var relay_time := 0.0
var relay_step := 0
var relay_ready := false
var wrong_links := 0
var legacy_ending := false
var ending_pending := false


func setup(main: Node3D, show_title: bool) -> void:
	game = main
	valley = game.valley
	pilot = game.pilot
	add_child(sites)
	sites.build(valley)
	sites.hide()
	sites.process_mode = Node.PROCESS_MODE_DISABLED
	station.name = "WeatherStations"
	add_child(station)
	station.build(valley, sites.tunnel_center)
	station.set_live(false)
	sites.points.merge(station.door_points)
	add_child(windgate)
	windgate.build(valley, sites.tunnel_center)
	add_child(incident)
	incident.build(valley)
	add_child(guardian)
	guardian.setup(pilot, sites.guardian_origin)
	guardian.hide()
	guardian.struck.connect(_struck)
	guardian.alert_changed.connect(_on_guardian_alert)
	aircraft = AIRCRAFT.instantiate()
	add_child(aircraft)
	_reset_aircraft()
	aircraft.hide()
	aircraft.process_mode = Node.PROCESS_MODE_DISABLED
	aircraft.landed.connect(_landed)
	aircraft.crashed.connect(_crashed)
	add_child(audio)
	add_child(ui)
	ui.new_game_requested.connect(start_new_game)
	ui.continue_requested.connect(_continue_from_title)
	ui.save_requested.connect(save_progress)
	ui.quality_changed.connect(_set_quality)
	ui.deduction_submitted.connect(submit_deduction)
	ui.cue_requested.connect(audio.play_cue)
	ui.quit_requested.connect(audio.stop_all)
	ui.modal_changed.connect(_on_modal)
	ui.windgate_choice.connect(_choose_windgate)
	ui.ending_requested.connect(_show_victory)
	flare = OmniLight3D.new()
	flare.light_color = Color("#ffab6d")
	flare.light_energy = 2.2
	flare.omni_range = 10.0
	flare.hide()
	pilot.add_child(flare)
	flare.position = Vector3(-0.45, 1.48, 0)
	_build_ending_light()
	if show_title:
		await get_tree().physics_frame
		await get_tree().physics_frame
	ui.configure(show_title, FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".previous"))
	if not show_title and not running:
		ui.hide()


func start_new_game(write_checkpoint := true) -> void:
	persistence_enabled = write_checkpoint
	if aircraft.is_piloted():
		_reset_aircraft()
	_begin()
	case_file = CaseFile.new()
	incident.reset()
	windgate.reset()
	health = 100.0
	exposure = 0.0
	supplies = 1
	flares = 0
	flare_clock = 0.0
	landed_observatory = false
	cache_open = false
	cache_steps = 0
	sites.cache_lid.rotation.x = 0.0
	sunrise = 0.0
	relay_ready = false
	_reset_relay()
	wrong_links = 0
	legacy_ending = false
	ending_pending = false
	ending_rays.hide()
	guardian.reset_guard()
	game.reset_seals(0)
	game.checkpoint = game.opening_spawn()
	pilot.respawn(game.checkpoint)
	pilot.orbit.rotation.y = -0.51
	pilot.stamina = 100.0
	_reset_aircraft()
	_discover("Mara's expedition camp")
	_refresh_case()
	if write_checkpoint:
		ui.show_opening()
	else:
		ui.notify("Follow Mara's distress call. Investigate the abandoned camp.")
	if write_checkpoint:
		save_progress()


func _begin() -> void:
	running = true
	station.set_live(true)
	ui.show()
	sites.show()
	sites.process_mode = Node.PROCESS_MODE_INHERIT
	aircraft.show()
	aircraft.process_mode = Node.PROCESS_MODE_INHERIT
	guardian.show()
	guardian.enabled = true
	pilot.survival_enabled = true


func play_step(delta: float) -> bool:
	if not running:
		return false
	if ending_pending:
		return true
	aircraft.wind_strength = valley.storm_strength
	var on_foot: bool = not aircraft.is_piloted()
	var active_at: Vector3 = pilot.global_position if on_foot else aircraft.global_position
	var surface_speed := Vector2(pilot.velocity.x, pilot.velocity.z).length()
	audio.follow(delta, active_at, surface_speed, on_foot and pilot.is_on_floor(),
		pilot.in_shelter, valley._last_lightning)
	if windgate.advance(delta, valley.storm_strength, active_at, case_file):
		save_progress()
		if on_foot and pilot.global_position.distance_to(windgate.point(Windgate.BOARD)) < 29.0:
			ui.notify("Windgate's warning bell sounds. Lysa has missed her check-in.")
	var incident_message := incident.advance(delta, pilot, valley.storm_strength, case_file, on_foot)
	if not incident_message.is_empty():
		ui.notify(incident_message)
		save_progress()
	if aircraft.is_piloted():
		if Input.is_action_just_pressed("restore") and not aircraft.disembark():
			ui.notify("Touch down and brake below 4 m/s to exit.")
		return true
	_update_survival(delta)
	if relay_time > 0.0:
		relay_time = maxf(0.0, relay_time - delta)
		if relay_time == 0.0:
			retry_checkpoint("The surge tripped the relay. Mara brings the console back online.")
			return true
	if Input.is_action_just_pressed("heal") and health < 100.0 and supplies > 0:
		supplies -= 1
		health = minf(100.0, health + 42.0)
		audio.play_cue(&"rest")
		ui.notify("Dressing applied. One medical supply used.")
	if Input.is_action_just_pressed("flare") and flares > 0:
		flares -= 1
		flare_clock = 16.0
		if guardian.global_position.distance_to(pilot.global_position) < 18.0:
			guardian.repel()
		ui.notify("The flare will hold the sentinel back briefly.")
	if Input.is_action_just_pressed("restore"):
		var id := _nearest_interaction()
		if not id.is_empty():
			_interact(id)
			return true
	return false


func presentation(delta: float) -> bool:
	if not running:
		return false
	report_timer -= delta
	if report_timer <= 0.0:
		report_timer = 0.13
		var danger := ""
		if guardian.state == Guardian.HUNTING:
			danger = "SENTINEL PURSUIT"
		elif guardian.state == Guardian.SUSPICIOUS:
			danger = "SENTINEL ALERT"
		elif pilot.crouching:
			danger = "CROUCHED"
		ui.set_status(health, pilot.stamina, exposure, supplies, danger)
		ui.set_flight(aircraft.is_piloted(), aircraft.speed, aircraft.altitude(), aircraft.throttle,
			aircraft.engine_running, aircraft.is_grounded())
		audio.set_mood(maxf(float(guardian.state) * 0.28, exposure * 0.007), valley.storm_strength, aircraft.is_piloted())
		_update_score()
		for id in sites.beacons:
			sites.beacons[id].visible = _can_interact(id)
		sites.beacons["publish"].visible = _can_interact("publish") or _can_interact("spire_start") or _can_interact("anchor_core")
		sites.beacons["rescue"].visible = _can_interact("rescue") or _can_interact("anchor_east")
		_refresh_mood()
		station.update_weather(valley.storm_strength, valley._quality)
	if ending_rays.visible:
		sunrise += delta
		ending_rays.scale.x = 1.0 + sin(sunrise * 1.7) * 0.13
		ending_rays.scale.z = ending_rays.scale.x
		ending_rays.visible = sunrise < 23.0
	var at: Vector3 = pilot.global_position
	var nearby := "" if aircraft.is_piloted() else _nearest_interaction()
	if aircraft.is_piloted():
		if aircraft.global_position.z > -174.0:
			game.show_goal("Fly east of the Sunken Spire", "Take off north. Pass the tower on its river side.",
				Vector3(3, 33, -158), true)
			return true
		var distance: float = aircraft.global_position.distance_to(sites.observatory)
		game.show_goal("Fly to the north observatory", "Land on the amber-marked runway   ·   %d m" % roundi(distance),
			sites.observatory + Vector3.UP * 3, true)
		return true
	if FloodGauge.LABELS.has(nearby):
		game.show_goal(_chapter(), "E   " + FloodGauge.LABELS[nearby], Vector3.ZERO, false)
		return true
	if Windgate.PEOPLE.has(nearby) or Windgate.LABELS.has(nearby):
		game.show_goal(_chapter(), "E   " + windgate.title_for(nearby), Vector3.ZERO, false)
		return true
	if not case_file.ending.is_empty():
		if _show_incident_lead(at):
			return true
		game.show_goal("Campaign complete", "J   Journal   ·   Esc   View ending", Vector3.ZERO, false)
		return true
	if relay_time > 0.0:
		var next: String = RELAY_ORDER[relay_step]
		if nearby == next:
			game.show_goal(_chapter(), "E   " + _interaction_label(next) + _relay_clock(), sites.points[next], false)
		else:
			_point_goal(next, at)
		return true
	if nearby == "aircraft":
		game.show_goal(game.objective.text, "E   Board the expedition aircraft", Vector3.ZERO, false)
		return true
	if not nearby.is_empty():
		game.show_goal(_chapter(), "E   " + _interaction_label(nearby) + _relay_clock(), sites.points[nearby], false)
		return true
	if landed_observatory and not case_file.collected.has("flight_log") and at.distance_to(sites.observatory) < 64.0:
		var recorder: Vector3 = sites.points["flight_log"]
		game.show_goal("Inspect the observatory recorder", "Independent evidence of the diversion", recorder, true)
		return true
	if _show_incident_lead(at):
		return true
	_show_campaign_goal(at)
	return true


func _show_incident_lead(at: Vector3) -> bool:
	if not incident.started or case_file.collected.has(FloodGauge.DISPATCH) or not incident.is_near(at):
		return false
	if game.step < game.shrines.size() and at.distance_to(game.shrines[game.step].global_position) < 6.0:
		return false
	var lead := incident.next_lead(case_file)
	var target := incident.point(lead)
	game.show_goal(FloodGauge.TITLE, "%s   ·   %d m" % [FloodGauge.LABELS[lead], roundi(at.distance_to(target))],
		target + Vector3.UP * 0.45, true)
	return true


func _nearest_interaction() -> String:
	var at: Vector3 = pilot.global_position + Vector3.UP * 0.4
	var closest := INTERACT_RANGE
	var candidate := ""
	for id in sites.points:
		var distance: float = at.distance_to(sites.points[id])
		if distance < closest and _can_interact(id):
			closest = distance
			candidate = id
	for id: String in FloodGauge.LABELS:
		if incident.can_interact(id, case_file):
			var distance := at.distance_to(incident.point(id))
			if distance < closest:
				closest = distance
				candidate = id
	for id: String in Windgate.PEOPLE.keys() + Windgate.LABELS.keys():
		if windgate.can_use(id, case_file):
			var distance := at.distance_to(windgate.point(id))
			if distance < closest:
				closest = distance
				candidate = id
	if candidate.is_empty() and aircraft.is_grounded() and aircraft.speed < 4.0 and at.distance_to(aircraft.global_position) < 5.0:
		return "aircraft"
	return candidate


func _can_interact(id: String) -> bool:
	if id == "publish" or id == "rescue":
		return _chapter_index() == 4 and relay_ready and case_file.ending.is_empty()
	if id == "spire_start":
		return _chapter_index() == 4 and relay_time == 0.0 and not relay_ready and case_file.ending.is_empty()
	if id in RELAY_ORDER:
		return relay_time > 0.0
	if id.ends_with("_rest"):
		return true
	if id.begins_with("rune_"):
		return not cache_open
	if case_file.collected.has(id):
		return false
	if id == "relay" or id == "manifest":
		return case_file.camp_complete()
	if id == "court":
		return windgate.rescued and game.step == game.shrines.size()
	return true


func _interact(id: String) -> void:
	if station.doors.has(id):
		var opened := station.toggle_door(id)
		ui.notify("Door opened." if opened else "Door closed.")
		audio.play_spatial(&"latch", station.door_points[id], -16.0)
		return
	if Windgate.PEOPLE.has(id) or Windgate.LABELS.has(id):
		_interact_windgate(id)
		return
	if id == "aircraft":
		if aircraft.board(pilot):
			_discover("West wind airstrip")
			_refresh_case()
			ui.notify("Head north along the river. The observatory runway is marked in amber.")
		return
	if id.ends_with("_rest"):
		health = 100.0
		exposure = 0.0
		pilot.stamina = 100.0
		game.checkpoint = sites.points[id] + Vector3.UP * 0.28
		guardian.reset_guard()
		audio.play_cue(&"rest")
		ui.notify("Rested. Health, stamina and warmth restored.")
		save_progress()
		return
	if id == "publish" or id == "rescue":
		_end_case(id)
		return
	if id == "spire_start":
		_start_relay()
		return
	if id in RELAY_ORDER:
		_ground_anchor(id)
		return
	if id.begins_with("rune_"):
		_turn_cache(id)
		return
	if id == FloodGauge.WITNESS or id == FloodGauge.TALK:
		var reply := incident.speak(case_file)
		if id == FloodGauge.WITNESS:
			_collect(id)
		else:
			save_progress()
		ui.notify(reply, 5.6)
		pilot.focus_conversation(incident.point(id) + Vector3.UP * 0.68)
		return
	_collect(id)


func _interact_windgate(id: String) -> void:
	if not windgate.can_use(id, case_file):
		return
	if Windgate.PEOPLE.has(id):
		var line := windgate.speak(id, case_file)
		if id == "noah" and windgate.vanished_at >= 0.0:
			_collect(Windgate.WITNESS)
		pilot.focus_conversation(windgate.point(id) + Vector3.UP * 0.58)
		ui.notify(line, 6.8)
		save_progress()
		return
	if id == Windgate.BOARD:
		if not windgate.ready_to_reconstruct(case_file):
			ui.notify("Find the pump register, Iris's tower recording, and either Lysa's satchel or Noah's receipt.", 5.5)
		elif windgate.exposed:
			ui.notify("Find Lysa at Intake Four. Follow the forest road to the west tunnel.")
		elif windgate.reconstructed:
			ui.ask_windgate("Who used the west gate key and sent Lysa to the intake?", Windgate.ACCUSATION)
		else:
			ui.ask_windgate("Which sequence fits the times in the register and on Iris's tape?", Windgate.RECONSTRUCTION)
		return
	if id == Windgate.RESCUE:
		windgate.rescued = true
		game.checkpoint = sites.points["tunnel_rest"] + Vector3.UP * 0.28
		_collect("windgate_end")
		ui.show_ending(Windgate.TITLE,
			"Lysa is alive. Pike listed prisoners as flood casualties so the Directorate could sell their land. Lysa gives you his override stamp. It can unlock Mara's sealed record at the Hanging Court.")
		return
	_collect(id)


func _choose_windgate(choice: String) -> void:
	if not windgate.ready_to_reconstruct(case_file):
		return
	var update := windgate.choose(choice)
	if not update.is_empty():
		windgate.refresh(case_file)
		ui.notify(update, 5.8)
		audio.play_cue(&"evidence")
		save_progress()


func _turn_cache(id: String) -> void:
	# The symbols can be read without the slate, so discovery never blocks the puzzle.
	if id == CACHE_ORDER[cache_steps]:
		cache_steps += 1
	else:
		cache_steps = 1 if id == CACHE_ORDER[0] else 0
	if cache_steps == CACHE_ORDER.size():
		cache_open = true
		sites.cache_lid.rotation.x = -0.9
		supplies += 2
		_discover("Caretaker's supply cache")
		_refresh_case()
		save_progress()
		ui.notify("Supply cache unlocked. Recovered two medical dressings.")
		audio.play_cue(&"seal")
	else:
		ui.notify("The cache answers with %d chimes." % cache_steps if cache_steps else "The cache falls silent. The runes reset.")
		audio.play_cue(&"evidence")


func _collect(id: String) -> void:
	if not case_file.record(id):
		return
	var item: Array = CaseFile.EVIDENCE[id]
	if id == "kit":
		supplies += 1
		flares += 1
		ui.notify("Recovered a medical dressing and one flare. G lights the flare.")
	else:
		ui.notify("%s added to journal   ·   J to read" % item[0])
	match id:
		"tracks":
			_discover("West ridge survey tracks")
		"relay", "manifest":
			_discover("Intake Four river tunnel")
		"court":
			game.checkpoint = game.shrines[1].global_position + Vector3(0, 0.8, 4.0)
			_discover("The Hanging Court")
		"runes":
			_discover("The Hanging Court")
		"flight_log":
			_discover("North observatory")
			if landed_observatory:
				ui.notify("Flight mission complete. The recorder confirms the diversion.")
		FloodGauge.DISPATCH:
			_discover("The old flood gauge")
			ui.notify("Robbery solved. The dispatch names the families who were charged ransom.")
	audio.play_cue(&"radio" if id == "radio" or id == "court" else &"evidence")
	_refresh_case()
	save_progress()


func _expedition_lead() -> String:
	for id in ["journal", "radio", "tracks", "relay", "manifest"]:
		if not case_file.collected.has(id):
			return id
	return ""


func _chapter_index() -> int:
	if not _expedition_lead().is_empty():
		return 0
	if game.step < game.shrines.size():
		return 1
	if not windgate.rescued:
		return 2
	if not case_file.solved or not case_file.collected.has("court"):
		return 3
	return 4


func _chapter() -> String:
	return CHAPTERS[_chapter_index()]


func can_restore_seal() -> bool:
	return not running or _expedition_lead().is_empty()


func _show_campaign_goal(at: Vector3) -> void:
	match _chapter_index():
		0:
			_point_goal(_expedition_lead(), at)
		1:
			var target: Vector3 = game.shrines[game.step].global_position
			if game.step == 1 and _show_windgate_updraft(at, target):
				return
			var distance := at.distance_to(target)
			var detail := "%d / 3   ·   %s   ·   %d m" % [game.step, game.SITE_NAMES[game.step], roundi(distance)]
			if distance < 6.0:
				detail = "E   Restore the %s seal" % game.SITE_NAMES[game.step]
			elif game._near_restored_updraft(at):
				detail = "E   Ride updraft   ·   Hold Space to glide toward " + game.SITE_NAMES[game.step]
			game.show_goal(_chapter(), detail, target + Vector3.UP * 4.6, distance >= 6.0)
		2:
			var lead := windgate.campaign_lead(case_file)
			_goal_at(windgate.title_for(lead), windgate.point(lead), at)
		3:
			if case_file.collected.has("court"):
				game.show_goal(_chapter(), "J   Link records that establish diversion, custody and intent",
					Vector3.ZERO, false)
			elif not _show_windgate_updraft(at, sites.points["court"]):
				_point_goal("court", at)
		4:
			if relay_ready:
				var target: Vector3 = sites.points["publish"]
				game.show_goal(_chapter(), "Choose the Spires' future   ·   Restore or safely disable", target, true)
			else:
				_point_goal("spire_start", at)


func _show_windgate_updraft(at: Vector3, court: Vector3) -> bool:
	if at.y >= court.y - 4.0 or pilot.launched or pilot.gliding:
		return false
	var windgate_shrine: Vector3 = game.shrines[0].global_position
	if at.distance_to(windgate_shrine) < 6.0:
		game.show_goal(_chapter(), "E   Ride the updraft   ·   Hold Space to glide to the Court", court, true)
	else:
		_goal_at("Reach the Court via Windgate's updraft", windgate_shrine, at)
	return true


func _point_goal(id: String, at: Vector3) -> void:
	_goal_at(_interaction_label(id) + _relay_clock(), sites.points[id], at)


func _goal_at(detail: String, target: Vector3, at: Vector3) -> void:
	game.show_goal(_chapter(), "%s   ·   %d m" % [detail, roundi(at.distance_to(target))],
		target + Vector3.UP * 0.8, true)


func _relay_clock() -> String:
	return "   ·   %d s" % ceili(relay_time) if relay_time > 0.0 else ""


func _interaction_label(id: String) -> String:
	if ACTIONS.has(id):
		return ACTIONS[id]
	var clue: Array = CaseFile.EVIDENCE[id]
	return "Inspect " + clue[0]


func on_seal_restored(index: int) -> void:
	if not running:
		return
	_discover(game.SITE_NAMES[index])
	if index == game.shrines.size() - 1:
		windgate.trigger_disappearance(case_file)
		ui.notify("The third seal carries a warning bell. Lysa is missing from Windgate.", 6.0)
	else:
		ui.notify("Seal restored. Its updraft is open. Hold Space to glide.")
	audio.play_cue(&"seal")
	_refresh_case()
	save_progress()


func submit_deduction(selection: PackedStringArray) -> void:
	if _chapter_index() != 3 or not case_file.deduction_available():
		return
	if not case_file.deduce(selection):
		wrong_links += 1
		exposure = minf(exposure + 12.0, 85.0) if exposure < 85.0 else exposure
		_refresh_case()
		ui.notify("The relay rejects the theory and vents cold mist. Recheck the diversion, custody and intent.", 6.0)
		save_progress()
		return
	_refresh_case()
	audio.play_cue(&"evidence")
	ui.notify("Pike sabotaged the Spires for Vesper. Mara's live channel is open at the Final Spire.", 6.0)
	save_progress()


func _start_relay() -> void:
	if not _can_interact("spire_start"):
		return
	var console: Vector3 = sites.points["spire_start"]
	game.checkpoint = console + Vector3(0.0, -0.50, 1.8)
	relay_step = 0
	relay_time = RELAY_TIME
	audio.play_cue(&"radio")
	ui.notify("Mara: I'm beneath the relay with the crew. Ground east, west, then core before the surge hits.", 6.0)
	save_progress()


func _ground_anchor(id: String) -> void:
	if relay_time <= 0.0:
		return
	if id != RELAY_ORDER[relay_step]:
		retry_checkpoint("The charge rebounded. Ground east, west, then core on the next attempt.")
		return
	relay_step += 1
	audio.play_cue(&"seal")
	if relay_step < RELAY_ORDER.size():
		return
	_reset_relay()
	relay_ready = true
	ui.notify("Mara: The crew is out. The islands can now settle safely if you cut the Spires loose.", 6.0)
	save_progress()


func _reset_relay() -> void:
	relay_time = 0.0
	relay_step = 0


func _end_case(choice: String) -> void:
	if not _can_interact(choice):
		return
	case_file.ending = choice
	ending_pending = true
	if choice == "rescue":
		game.dim_seals()
	ending_rays.position = game.shrines[2].global_position + Vector3.UP * 28.0
	var surface := ending_rays.material_override as StandardMaterial3D
	surface.emission = Color("#77ffdc") if choice == "rescue" else Color("#ffb978")
	ending_rays.show()
	sunrise = 0.0
	pilot.focus_conversation(ending_rays.global_position - Vector3.UP * 22.0)
	audio.play_cue(&"ending")
	_refresh_case()
	save_progress()
	await get_tree().create_timer(2.4, false).timeout
	if case_file.ending == choice:
		ending_pending = false
		_show_victory()


func _show_victory() -> void:
	if case_file.ending.is_empty():
		return
	if legacy_ending:
		ui.show_ending("The Last Transmission", "Your expedition case is recorded in the field journal.", true)
	elif case_file.ending == "publish":
		ui.show_ending("The Spires Awaken",
			"The islands hold as the Spires come back into balance. Mara returns with her crew and broadcasts Pike's orders from the Court. At dawn, the valley opens the Spires to keepers chosen by its own settlements.", true)
	else:
		ui.show_ending("A Sky of Our Own",
			"The anchors release in sequence. Island by island, the Frontier settles onto the old ridgelines. The last broadcast carries Mara's evidence beyond the mountains. At dawn, Windgate opens a road that has been under water for a hundred years.", true)


func _update_survival(delta: float) -> void:
	var at: Vector3 = pilot.global_position
	var local: Vector3 = at - sites.tunnel_center
	pilot.in_shelter = absf(local.x) < 4.1 and absf(local.z) < 2.3 and local.y < 2.1
	var sheltered := false
	for id in ["camp_rest", "tunnel_rest", "airstrip_rest"]:
		if at.distance_to(sites.points[id]) < 8.5:
			sheltered = true
			break
	var storm: float = valley.storm_strength
	var pressure := storm * (4.7 if pilot.gliding else 3.1)
	var change := -8.0 if sheltered or pilot.in_shelter else pressure - 0.75
	exposure = clampf(exposure + delta * change, 0.0, 100.0)
	if exposure > 90.0:
		_damage(delta * 3.6)
	flare_clock = maxf(0.0, flare_clock - delta)
	flare.visible = flare_clock > 0.0


func on_hazard() -> void:
	if running:
		if health > 25.0:
			health -= 25.0
			retry_checkpoint("Dangerous terrain. Returned to your last shelter or seal.", false)
		else:
			retry_checkpoint("The fall was fatal. Retrying from your last checkpoint.")


func _struck() -> void:
	_damage(21.0)
	audio.play_cue(&"danger")


func _damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		retry_checkpoint("You fell. Retrying from your last checkpoint.")


func retry_checkpoint(message: String, recover := true) -> void:
	_reset_relay()
	if recover:
		health = 100.0
		exposure = 0.0
		pilot.stamina = 100.0
	pilot.respawn(game.checkpoint)
	guardian.reset_guard()
	ui.notify(message)


func _on_guardian_alert(state: int) -> void:
	if state == Guardian.HUNTING:
		ui.notify("The sentinel has your trail. Break line of sight or use a flare.")
		audio.play_cue(&"danger")


func _landed(at: Vector3) -> void:
	if absf(at.x - sites.observatory.x) < 8.0 and absf(at.z - sites.observatory.z) < 52.0 and absf(at.y - sites.observatory.y) < 3.0:
		landed_observatory = true
		_discover("North observatory runway")
		ui.notify("Observatory landing confirmed. Brake, exit, and search the recorder.")
		_refresh_case()
		save_progress()


func _crashed() -> void:
	if running:
		_damage(23.0)
		ui.notify("Hard impact. The aircraft has been recovered to the departure strip.")


func _reset_aircraft() -> void:
	aircraft.configure_spawn(sites.departure + Vector3(0, 0, 39.0), 0.0)


func _refresh_case() -> void:
	incident.refresh(case_file)
	windgate.refresh(case_file)
	station.set_rescue_open(windgate.rescued)
	var status := case_file.deduction_status()
	if wrong_links > 0 and not case_file.solved:
		status += " Rejected reconstructions   %d" % wrong_links
	ui.set_journal(CaseFile.TITLE, CaseFile.QUESTION, case_file.journal_entries(), case_file.discoveries,
		status, _chapter_index() == 3 and case_file.deduction_available())
	ui.campaign_complete = not case_file.ending.is_empty()


func _discover(location_name: String) -> void:
	case_file.discover(location_name)


func _refresh_mood() -> void:
	var phase: float = [0.16, 0.40, 0.62, 0.74, 0.88][_chapter_index()]
	var calm := 0.0
	if relay_time > 0.0:
		phase = 0.98
	if not case_file.ending.is_empty():
		phase = 0.22 if case_file.ending == "publish" else 0.33
		calm = 0.72 if case_file.ending == "publish" else 1.0
	valley.set_frontier_mood(phase, calm)


func _set_quality(level: int) -> void:
	valley.set_quality(level)


func _on_modal(active: bool) -> void:
	game.hud_layer.visible = not active
	_update_score()


func _update_score() -> void:
	var cue: StringName = &"explore"
	if ui._modal in ["ending", "credits"] or ending_pending:
		cue = &"reveal"
	elif ui._modal == "title" or (ui._modal == "settings" and ui._settings_from == "title") or not running:
		cue = &"title"
	elif aircraft.is_piloted():
		cue = &"flight"
	elif guardian.state == Guardian.HUNTING or relay_time > 0.0:
		cue = &"chase"
	elif case_file.ending.is_empty() and _chapter_index() in [2, 3]:
		cue = &"investigate"
	elif guardian.state == Guardian.SUSPICIOUS or ui._modal == "journal" or incident.is_near(pilot.global_position) \
			or pilot.global_position.distance_to(sites.tunnel_center) < 20.0:
		cue = &"investigate"
	audio.set_score(cue, pilot._conversation_time > 0.0 or ui._modal == "pause")


func _continue_from_title() -> void:
	if not load_progress():
		ui.call_deferred("return_to_title")
	elif not case_file.ending.is_empty():
		_show_victory()


func save_progress() -> void:
	if not running or not persistence_enabled:
		return
	var file := ConfigFile.new()
	file.set_value("state", "format", 2)
	file.set_value("state", "seals", game.step)
	file.set_value("state", "checkpoint", game.checkpoint)
	file.set_value("state", "clues", case_file.collected)
	file.set_value("state", "discoveries", case_file.discoveries)
	file.set_value("state", "solved", case_file.solved)
	file.set_value("state", "ending", case_file.ending)
	file.set_value("state", "relay_ready", relay_ready)
	file.set_value("state", "wrong_links", wrong_links)
	file.set_value("state", "legacy_ending", legacy_ending)
	file.set_value("state", "health", health)
	file.set_value("state", "exposure", exposure)
	file.set_value("state", "supplies", supplies)
	file.set_value("state", "flares", flares)
	file.set_value("state", "landed", landed_observatory)
	file.set_value("state", "cache_open", cache_open)
	incident.save_to(file)
	windgate.save_to(file)
	var previous := ProjectSettings.globalize_path(save_path + ".previous")
	var temporary := ProjectSettings.globalize_path(save_path + ".next")
	var current := ProjectSettings.globalize_path(save_path)
	var error := file.save(temporary)
	if error == OK:
		if FileAccess.file_exists(current):
			if _read_checkpoint(current) == null:
				error = DirAccess.remove_absolute(current)
			else:
				DirAccess.remove_absolute(previous)
				error = DirAccess.rename_absolute(current, previous)
		if error == OK:
			error = DirAccess.rename_absolute(temporary, current)
	if error != OK:
		ui.notify("Save failed. The previous checkpoint is still available.")
	else:
		ui.set_continue_available(true)


func load_progress() -> bool:
	var file := _read_checkpoint(save_path)
	if file == null:
		file = _read_checkpoint(save_path + ".previous")
	if file == null:
		ui.notify("No readable checkpoint is available.")
		return false
	_begin()
	persistence_enabled = true
	case_file = CaseFile.new()
	for id in file.get_value("state", "clues", PackedStringArray()):
		case_file.record(id)
	for location_name in file.get_value("state", "discoveries", PackedStringArray()):
		case_file.discover(location_name)
	incident.load_from(file)
	windgate.load_from(file)
	case_file.solved = bool(file.get_value("state", "solved", false))
	case_file.ending = String(file.get_value("state", "ending", ""))
	legacy_ending = bool(file.get_value("state", "legacy_ending",
		file.get_value("state", "format") == 1 and not case_file.ending.is_empty()))
	relay_ready = bool(file.get_value("state", "relay_ready", false))
	wrong_links = maxi(0, int(file.get_value("state", "wrong_links", 0)))
	ending_pending = false
	flare_clock = 0.0
	flare.hide()
	_reset_relay()
	health = clampf(float(file.get_value("state", "health", 100.0)), 1.0, 100.0)
	exposure = clampf(float(file.get_value("state", "exposure", 0.0)), 0.0, 100.0)
	supplies = clampi(int(file.get_value("state", "supplies", 1)), 0, 99)
	flares = clampi(int(file.get_value("state", "flares", 0)), 0, 99)
	landed_observatory = bool(file.get_value("state", "landed", false))
	cache_open = bool(file.get_value("state", "cache_open", false))
	cache_steps = 0
	sites.cache_lid.rotation.x = -0.9 if cache_open else 0.0
	game.reset_seals(clampi(int(file.get_value("state", "seals", 0)), 0, 3))
	if case_file.ending == "rescue" and not legacy_ending:
		game.dim_seals()
	game.checkpoint = file.get_value("state", "checkpoint")
	if game.step == game.shrines.size() and not windgate.rescued:
		windgate.trigger_disappearance(case_file)
	pilot.respawn(game.checkpoint)
	pilot.stamina = 100.0
	_reset_aircraft()
	guardian.reset_guard()
	ending_rays.hide()
	_refresh_case()
	ui.notify("Last checkpoint restored.")
	return true


func _read_checkpoint(path: String) -> ConfigFile:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return null
	var saved_checkpoint: Variant = file.get_value("state", "checkpoint", null)
	if file.get_value("state", "format", 0) not in [1, 2] or not saved_checkpoint is Vector3 \
			or not saved_checkpoint.is_finite():
		return null
	for key in ["clues", "discoveries"]:
		var entries: Variant = file.get_value("state", key, PackedStringArray())
		if not entries is PackedStringArray and not entries is Array:
			return null
		for entry in entries:
			if not entry is String:
				return null
	return file


func _build_ending_light() -> void:
	var beam := CylinderMesh.new()
	beam.top_radius = 0.08
	beam.bottom_radius = 0.92
	beam.height = 54.0
	var surface := StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.albedo_color = Color(0.7, 0.93, 0.85, 0.35)
	surface.emission_enabled = true
	surface.emission_energy_multiplier = 2.5
	ending_rays = MeshInstance3D.new()
	ending_rays.mesh = beam
	ending_rays.material_override = surface
	ending_rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ending_rays)
	ending_rays.hide()
