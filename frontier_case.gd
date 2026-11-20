extends RefCounted

const TITLE := "The Last Transmission"
const QUESTION := "What happened to Mara Vale's expedition?"
const EVIDENCE := {
	"journal": ["Mara's field journal", "Mara was due home before the thaw. Her last entry says a survey crew in blank coats arrived with instructions to retune the Hanging Court. She copied their relay mark into the margin."],
	"radio": ["Broken field radio", "The receiver is still tuned to 81.4. Beneath the static, Mara repeats: 'If you hear the bell, do not follow the lights. They have our route.' The transmit valve has been pulled."],
	"tracks": ["Two sets of tracks", "Someone walked down from the west ridge in clean boots, then dragged a heavy crate toward the old river tunnel. Mara's party wore hobnailed field boots."],
	"kit": ["Cut harness and flare", "The harness buckle has a survey stamp. Its straps were severed cleanly. A fresh red flare is wedged in the roll beneath it."],
	"relay": ["Timed relay", "The relay from the river tunnel stored a command at 02:14: divert the expedition's aircraft beacon from the landing strip to Intake Four. It authenticated with the same mark from Mara's journal."],
	"manifest": ["Intake Four manifest", "A Vesper Directorate custody manifest lists six expedition members, received alive at 02:28. The official accident bulletin was filed at 02:10, four minutes before the diversion."],
	"court": ["Court operator's record", "Mara left a voice record inside the console. The Directorate diverted their flight to seize the expedition's calibration. She copied the original command and locked it into the Sunken Spire. Intake Four remains occupied."],
	"flight_log": ["Observatory flight recorder", "The observatory tracked a second aircraft shadowing Mara's flight. Its pilot called in the diversion before the emergency beacon lit. This is independent corroboration."],
	"runes": ["Caretaker's inscription", "The three seals govern the valley's wind and the Intake Four lock. Left together, they can open a route or send a signal past the mountains."],
	"vault_hint": ["A caretaker's supply slate", "The slate shows the order for opening the emergency cache. The crescent watches for dawn. The sun warms the spring. The current carries the heat home."],
	"intake_trace": ["Tally seal in the mud", "A Vesper tally seal lies beside a fresh gouge. The trail leads toward the disused flood gauge. The survey case was stripped, but something was dragged toward the gauge."],
	"intake_witness": ["Iven's statement", "The ferryman saw two blank coats strip the survey case. He hid the duplicate dispatch in the flood gauge before they came back for it. He heard them ask which families had paid."],
	"intake_dispatch": ["The ferryman's dispatch", "The duplicate pairs the names of detained families with ransom amounts and the same Vesper seal found at Intake Four. The collectors were paid to keep the missing off the official rolls."],
	"windgate_seal": ["Lysa's survey satchel", "Windgate case. Lysa left her double-entry ledger and a torn retaining slip by the west service route. The last margin note reads: When they call it a flood, check whether the pressure warning came before or after the master key."],
	"windgate_ledger": ["West gate lock register", "Windgate case. 21:12. Orrin Pike signs out the original key under Vale Sayer's name. The receipt for Vale's replacement is timestamped 21:23 at the airstrip. Orrin says he never left the north pump room."],
	"windgate_tape": ["Iris's backup recording", "Windgate case. 21:17. The west pressure alarm sounds. Lysa says, 'Pike, you made me come here. This is no inspection.' A second voice orders the Intake Four door shut."],
	"windgate_statement": ["Noah's key receipt", "Windgate case. Vale was in Noah's workshop from 21:06 until 21:23. The replacement key never left the bench before the alarm. This clears Vale even though the old lock register names him."],
	"windgate_end": ["Lysa's second ledger", "Lysa is alive. Her missing-person entries were filed as flood fatalities, then sold to a Vesper broker as vacant land. Mara hid the original transfer list at the North Observatory."],
}

var collected := PackedStringArray()
var discoveries := PackedStringArray()
var solved := false
var ending := ""


func record(id: String) -> bool:
	if not EVIDENCE.has(id) or collected.has(id):
		return false
	collected.append(id)
	return true


func discover(location_name: String) -> bool:
	if discoveries.has(location_name):
		return false
	discoveries.append(location_name)
	return true


func camp_complete() -> bool:
	return collected.has("journal") and collected.has("radio") and collected.has("tracks")


func deduction_available() -> bool:
	return collected.has("relay") and collected.has("manifest") and collected.has("court") and not solved


func deduce(selection: PackedStringArray) -> bool:
	if not deduction_available() or selection.size() != 3:
		return false
	if not selection.has("relay") or not selection.has("manifest") or not selection.has("court"):
		return false
	solved = true
	return true


func journal_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in collected:
		var clue: Array = EVIDENCE[id]
		result.append({"id": id, "title": clue[0], "text": clue[1]})
	return result


func deduction_status() -> String:
	if solved:
		return "The Directorate diverted the expedition, declared it lost in advance, and took its survivors into custody. Mara left proof at the Spire."
	if deduction_available():
		return "Select three records that show who diverted the flight, what happened to the crew, and whether the accident story was planned."
	return "Find the diversion command, proof that the crew survived, and a witness who can explain the link."
