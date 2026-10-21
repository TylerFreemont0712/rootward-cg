extends GdUnitTestSuite
## The chime task (ADR-0085, Pebblebrook) holds everything a task must (TaskCheck): its reference passes, its starter and
## its Builder's start do not, each block answer passes its stage, and no text gives the answer away.


func test_the_chime_task_holds_together() -> void:
	var found := TaskCheck.problems("chime")
	assert_array(found).override_failure_message("\n".join(found)).is_empty()
