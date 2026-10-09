extends Node
## Counts process time the way SceneTree timers do, for tests that check how
## long something waited.
##
## Timers advance by frame deltas, and the first delta a timer sees can include
## time from before it was created, so the wall clock can fall short of a
## timer's length. This clock's [method _process] runs in the same frame and
## with the same delta as the tree's timers, so the difference between a
## reading taken when a timer starts and one taken when it fires is exactly
## the time the timer counted.

## Process time counted since this clock entered the tree, in seconds.
var seconds := 0.0


func _process(delta: float) -> void:
	seconds += delta


## Waits for an idle frame and returns the reading at the start of the next
## one. A timer started right after this is charged only for the idle frame,
## not for whatever ran before it, such as test setup.
func start() -> float:
	await get_tree().process_frame
	await get_tree().process_frame
	return seconds
