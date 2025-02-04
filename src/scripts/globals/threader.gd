extends Node


var tasks: Array[Task] = []
var mutex: Mutex = Mutex.new()
var error: int = -1




func _process(_delta: float) -> void:
	for l_task: Task in tasks:
		if WorkerThreadPool.is_task_completed(l_task.id):
			error = WorkerThreadPool.wait_for_task_completion(l_task.id)

			if error:
				printerr("Error with task: ", l_task.id, " - Error: ", error)
			elif !l_task.after_task.is_null():
				l_task.after_task.call()

			tasks.remove_at(tasks.find(l_task))


class Task:
	var id: int = -1
	var after_task: Callable


	func _init(a_id: int, a_after_task: Callable = Callable()) -> void:
		id = a_id
		after_task = a_after_task

