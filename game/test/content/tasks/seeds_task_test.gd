extends GdUnitTestSuite
## The seeds task (ADR-0085, Pebblebrook) holds everything a task must (TaskCheck): its reference passes, its starter and
## its Builder's start do not, each block answer passes its stage, and no text gives the answer away.


func test_the_seeds_task_holds_together() -> void:
	var found := TaskCheck.problems("seeds")
	assert_array(found).override_failure_message("\n".join(found)).is_empty()
