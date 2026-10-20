extends "res://tools/overworld_shot.gd"
## The real DialogueBox with a broad cutout bust; isolated screenshot saves and actual town context.


func _ready() -> void:
	OS.set_environment("ROOTWARD_LANTERNTOWN", "talk")
	await super._ready()


func _play(screen: Node, base: String) -> void:
	await super._play(screen, base)
	var person: Dictionary = OverworldScreen.catalog_of().townsfolk.daro
	var talk := screen.get("_talk") as DialogueBox
	talk.say([{"text": "A quiet village lane makes a fine place for a tune.", "speaker": "", "mood": "happy"}], person)
	await _frames(20)
	_finish_typing(talk)
