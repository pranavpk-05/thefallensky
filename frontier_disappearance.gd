extends Node3D

const Resident = preload("res://frontier_resident.gd")
const TITLE := "The People Who Disappeared"
const SEAL := "windgate_seal"
const LEDGER := "windgate_ledger"
const RADIO := "windgate_tape"
const WITNESS := "windgate_statement"
const RESCUE := "windgate_rescue"
const BOARD := "windgate_board"
const PEOPLE := {
	"lysa": ["Lysa Morrow", "Water surveyor", "#7c6956", "#a97959", Vector4(-5.9, -61.0, -5.0, -63.5)],
	"orrin": ["Orrin Pike", "Pump supervisor", "#485454", "#a7735b", Vector4(-8.8, -59.1, -9.1, -61.5)],
	"vale": ["Vale Sayer", "Lock tender", "#647262", "#8c634e", Vector4(-2.3, -55.5, -1.5, -58.2)],
	"ada": ["Ada Quinn", "Field reporter", "#665749", "#b18269", Vector4(-3.75, -49.8, -3.15, -47.6)],
	"iris": ["Iris Rook", "Radio operator", "#626975", "#9d6d53", Vector4(7.25, 2.65, 5.8, 2.1)],
	"noah": ["Noah Reed", "Aircraft mechanic", "#786652", "#82664f", Vector4(-7.15, -79.4, -6.8, -76.6)],
	"marae": ["Marae Bell", "District medic", "#6f6469", "#825840", Vector4(-1.5, -61.85, -0.85, -59.3)],
	"ellis": ["Ellis Fen", "Stores keeper", "#516465", "#c29573", Vector4(-1.1, -56.9, -0.45, -54.8)],
}
const ORDINARY := {
	"lysa": "I keep two copies of every reading. Mara taught me that. If the tower rings twice, meet me by the stores.",
	"orrin": "Keep off the pump deck after dark. Lysa keeps asking why records need two signatures. Because she never ran a pump.",
	"vale": "My father taught me the locks. Orrin does the signing now. When he says the river went up, the Council takes his word.",
	"ada": "Mara sent me her notes before she went upriver. Half the entries say 'natural loss'. Ask who gets the land afterward.",
	"iris": "I keep the tower recordings. Once a man asked me to erase a distress call. You'll hear me say no on the tape.",
	"noah": "The Peregrine is airworthy. Mara promised to bring me back an intake serial number. All I got was an empty envelope.",
	"marae": "I treat the people Orrin sends downriver. I started writing their real names in my own book.",
	"ellis": "Vesper paints over the same crates every year. The addresses change, never the smell of river mud.",
}
const AFTER := {
	"orrin": "Vale had the only west-gate key. Check the lock register yourself. I was in the north pump room all shift.",
	"vale": "I lost the key two days ago. Ask Noah when he took my blade to the shop. Pike issued me a blank to finish my rounds.",
	"ada": "Write down what happened in order. Use the reconstruction board at the approach. The register and Iris's tape matter more than a hunch.",
	"iris": "The backup recording is at the tower. Listen for the timed pressure alarm under the voice. It puts the call at the west gate.",
	"noah": "Vale was with me. I sat beside him while we cut a new key. Pike already had the original. I stamped the duplicate myself.",
	"marae": "Lysa came to me shaking yesterday. She said Pike was recording people as flood deaths before they ever reached the intake.",
	"ellis": "Lysa showed me two sets of books. One says natural loss. The other gives a purchase price for the family's land.",
}
const LABELS := {
	SEAL: "Inspect Lysa's survey satchel",
	LEDGER: "Read the pump house register",
	RADIO: "Play the duplicate tower recording",
	BOARD: "Reconstruct the disappearance",
	RESCUE: "Release Lysa from Intake Four",
}
const RECONSTRUCTION := {
	"key_first": "Pike uses Vale's key, then the west alarm sounds.",
	"alarm_first": "The alarm sounds, then Vale opens the west gate.",
	"lysa_left": "Lysa leaves alone before either event.",
}
const ACCUSATION := {"orrin": "Name Orrin Pike", "vale": "Name Vale Sayer", "iris": "Name Iris Rook"}

var age := 0.0
var vanished_at := -1.0
var reconstructed := false
var exposed := false
var rescued := false
var wrong := 0
var trust: Dictionary = {}
var met: Dictionary = {}
var actors: Dictionary[String, Node3D] = {}
var points: Dictionary[String, Vector3] = {}
var _terrain
var _evidence_props: Dictionary[String, Node3D] = {}
var _talk_until: Dictionary[String, float] = {}
var _mover_clock := 0.0
var _alarm := false


func build(terrain: Node3D, intake: Vector3) -> void:
	_terrain = terrain
	var index := 0
	for id: String in PEOPLE:
		var profile: Array = PEOPLE[id]
		var person := Resident.new()
		person.name = profile[0].replace(" ", "")
		add_child(person)
		person.build(terrain, Color(profile[2]), Color(profile[3]), index)
		var itinerary: Vector4 = profile[4]
		person.pose(_ground(itinerary.x, itinerary.y), _ground(itinerary.z, itinerary.w), 0.0, false, false)
		actors[id] = person
		index += 1
	_add_marker(SEAL, _ground(-4.6, -61.25), Vector3(0.38, 0.25, 0.25), Color("#866046"))
	_add_marker(LEDGER, _ground(-9.1, -60.25), Vector3(0.40, 0.63, 0.28), Color("#6d614a"))
	_add_marker(RADIO, _ground(5.9, 1.2), Vector3(0.56, 0.94, 0.35), Color("#6a8675"))
	_add_marker(BOARD, _ground(-6.9, -47.9), Vector3(0.79, 1.20, 0.16), Color("#7f7460"))
	points[RESCUE] = intake + Vector3(-2.83, 0.95, -0.78)
	reset()
	hide()


func reset() -> void:
	age = 0.0
	vanished_at = -1.0
	wrong = 0
	reconstructed = false
	exposed = false
	rescued = false
	trust.clear()
	met.clear()
	_talk_until.clear()
	_mover_clock = 0.0
	_alarm = false


func save_to(file: ConfigFile) -> void:
	file.set_value("windgate", "age", age)
	file.set_value("windgate", "vanished_at", vanished_at)
	file.set_value("windgate", "reconstructed", reconstructed)
	file.set_value("windgate", "exposed", exposed)
	file.set_value("windgate", "rescued", rescued)
	file.set_value("windgate", "wrong", wrong)
	file.set_value("windgate", "trust", trust.duplicate())
	file.set_value("windgate", "met", met.duplicate())


func load_from(file: ConfigFile) -> void:
	reset()
	age = maxf(0.0, float(file.get_value("windgate", "age", 0.0)))
	vanished_at = float(file.get_value("windgate", "vanished_at", -1.0))
	reconstructed = bool(file.get_value("windgate", "reconstructed", false))
	exposed = bool(file.get_value("windgate", "exposed", false))
	rescued = bool(file.get_value("windgate", "rescued", false))
	wrong = maxi(0, int(file.get_value("windgate", "wrong", 0)))
	trust = file.get_value("windgate", "trust", {})
	met = file.get_value("windgate", "met", {})


func refresh(case_file: RefCounted) -> void:
	visible = case_file.camp_complete()
	if not visible:
		return
	for id in _evidence_props:
		_evidence_props[id].visible = vanished_at >= 0.0 and (id == BOARD or not case_file.collected.has(id))
	actors["lysa"].visible = vanished_at < 0.0 or rescued
	actors["orrin"].visible = not exposed


func advance(delta: float, storm: float, player: Vector3, case_file: RefCounted) -> bool:
	if not visible:
		return false
	age += delta
	_alarm = storm > 0.65
	var vanished := vanished_at < 0.0 and age >= 22.0 and (storm >= 0.4 or age >= 105.0)
	if vanished:
		trigger_disappearance(case_file)
	_mover_clock += delta
	if _mover_clock < 0.045:
		return vanished
	var step := _mover_clock
	_mover_clock = 0.0
	var missing := vanished_at >= 0.0 and not rescued
	for id in actors:
		var actor := actors[id]
		if not actor.visible:
			continue
		var route: Vector4 = PEOPLE[id][4]
		var home := Vector2(route.x, route.y)
		var work := Vector2(route.z, route.w)
		if id == "orrin" and missing and age - vanished_at > 38.0:
			home = Vector2(-7.95, -71.4)
			work = Vector2(-7.6, -69.0)
		var phase := fposmod(age + float(PEOPLE.keys().find(id) * 9), 108.0)
		var on_duty := smoothstep(17.0, 26.0, phase) * (1.0 - smoothstep(64.0, 78.0, phase))
		var position_on_route := home.lerp(work, 1.0 if _alarm else on_duty)
		if id == "lysa" and rescued:
			position_on_route = Vector2(-43.0, -66.1)
		if player.distance_squared_to(Vector3(position_on_route.x, player.y, position_on_route.y)) > 58.0 * 58.0:
			continue
		var talking: bool = float(_talk_until.get(id, -1.0)) > age
		var at: Vector3 = actor.position if talking else _ground(position_on_route.x, position_on_route.y)
		var facing := player if talking else _ground(work.x + 0.8, work.y - 0.32)
		actor.pose(at, facing, step, talking, on_duty > 0.94 and not _alarm)
	return vanished


func trigger_disappearance(case_file: RefCounted) -> void:
	if vanished_at < 0.0 and case_file.camp_complete():
		vanished_at = age
		refresh(case_file)


func campaign_lead(case_file: RefCounted) -> String:
	if exposed:
		return RESCUE
	for id in [LEDGER, RADIO]:
		if not case_file.collected.has(id):
			return id
	if not case_file.collected.has(SEAL) and not case_file.collected.has(WITNESS):
		return SEAL
	return BOARD


func title_for(id: String) -> String:
	return "%s, %s" % [PEOPLE[id][0], PEOPLE[id][1].to_lower()] if PEOPLE.has(id) else LABELS[id]


func can_use(id: String, case_file: RefCounted) -> bool:
	if not visible:
		return false
	if PEOPLE.has(id):
		return actors[id].visible
	if vanished_at < 0.0:
		return false
	if id == RESCUE:
		return exposed and not rescued
	if id == BOARD:
		return not rescued
	return not case_file.collected.has(id)


func point(id: String) -> Vector3:
	return actors[id].position + Vector3.UP * 0.88 if actors.has(id) else points[id]


func speak(id: String, case_file: RefCounted) -> String:
	var said := int(met.get(id, 0))
	met[id] = said + 1
	trust[id] = mini(3, int(trust.get(id, 0)) + 1)
	_talk_until[id] = age + 4.0
	var words: String = ORDINARY[id]
	if case_file.solved and id in ["ada", "lysa"]:
		words = "I heard Mara on the open channel. When the relay clears, I'll tell the families where to meet her crew."
	elif rescued and id in ["ada", "lysa"]:
		words = "Use Pike's stamp at the Hanging Court. Mara also left a transfer list at the North Observatory if you need a second copy."
	elif case_file.collected.has(LEDGER) and id == "orrin":
		words = "Those initials could belong to anyone. The river was already rising when I opened the west gate."
	elif case_file.collected.has(RADIO) and id == "iris":
		words = "That second voice came over a Directorate channel. I heard it again on the night Mara's beacon vanished."
	elif vanished_at >= 0.0 and AFTER.has(id):
		words = AFTER[id]
		if said > 0 and id == "noah" and wrong > 0:
			words = "You were wrong about Vale. The spare key is in the register. Read what's stamped under it this time."
	elif said > 0:
		words = "I meant what I said. Keep a copy of anything you find."
	return "%s: %s" % [PEOPLE[id][0], words]


func ready_to_reconstruct(case_file: RefCounted) -> bool:
	return case_file.collected.has(LEDGER) and case_file.collected.has(RADIO) and (
		case_file.collected.has(SEAL) or case_file.collected.has(WITNESS))


func choose(id: String) -> String:
	if not reconstructed:
		if not RECONSTRUCTION.has(id):
			return ""
		reconstructed = id == "key_first"
		return "The register entry precedes the alarm. Vale was still in the hangar." if reconstructed else \
			"The times conflict. Compare the recorded alarm with the lock register."
	if exposed or not ACCUSATION.has(id):
		return ""
	if id != "orrin":
		wrong += 1
		trust[id] = maxi(-3, int(trust.get(id, 0)) - 2)
		return "Your accusation doesn't hold. The name stays off the report. The witness will remember this."
	exposed = true
	return "Pike fled when Ada put the original register on air. Follow Lysa's signal to Intake Four."


func _add_marker(id: String, at: Vector3, size: Vector3, tint: Color) -> void:
	var surface: StandardMaterial3D = _terrain.material(tint)
	var body: MeshInstance3D = _terrain.box(self, at + Vector3.UP * (size.y * 0.5), size, surface)
	_evidence_props[id] = body
	points[id] = at + Vector3.UP * minf(0.95, size.y)
	if id == BOARD:
		var label := Label3D.new()
		label.text = "WINDGATE\nINCIDENT BOARD"
		label.pixel_size = 0.0049
		label.modulate = Color("#ead3a7")
		body.add_child(label)
		label.position = Vector3(0, 0.26, size.z * 0.52)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, _terrain.surface_height_at(x, z), z)
