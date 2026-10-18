class_name GopalaSaveSlots
extends RefCounted
## Slot one retains the existing schema-2 MVP filename and backup protocol.
var directory := "user://saves"
var error := ""
var _metadata := ConfigFile.new()

func path(slot: int) -> String:
	return directory+("/mvp.json" if slot == 0 else "/mvp-%d.json" % (slot+1))

func rows() -> Array[Dictionary]:
	_metadata.load(directory+"/slots.cfg")
	var result: Array[Dictionary] = []
	for slot in 3:
		var filename := path(slot)
		var exists := FileAccess.file_exists(filename)
		var service := GopalaSettlementSave.new()
		var state := service.read(filename) if exists else {}
		var valid: bool = not state.is_empty() and state.get("context",{}).get("mvp",false) == true
		result.append({"slot":slot,"name":str(_metadata.get_value(str(slot),"name","Settlement %d" % (slot+1))),"exists":exists,"valid":valid,"updated":maxi(int(_metadata.get_value(str(slot),"updated",0)),int(FileAccess.get_modified_time(filename))*1000) if exists else 0,"tick":int(state.get("clock",[0,0,0])[2]) if valid else 0})
	return result

func latest() -> int:
	var found := -1
	var stamp := -1
	for row in rows():
		if row.valid and int(row.updated) > stamp:
			found = row.slot
			stamp = row.updated
	return found

func record(slot: int, title: String) -> bool:
	_metadata.load(directory+"/slots.cfg")
	_metadata.set_value(str(slot),"name",title.strip_edges().left(40) if not title.strip_edges().is_empty() else "Settlement %d" % (slot+1))
	_metadata.set_value(str(slot),"updated",int(Time.get_unix_time_from_system()*1000.0))
	var result := _metadata.save(directory+"/slots.cfg")
	error = "" if result == OK else "Save succeeded, but the slot name could not be saved."
	return result == OK
