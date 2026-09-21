extends Node
## One event channel. GameState and its existing domain services own all records.
signal occurred(event: String, payload: Dictionary)
func publish(event: String, payload: Dictionary={}) -> void:
	occurred.emit(event,payload.duplicate(true))
