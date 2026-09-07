extends Node


var timed_tasks: Dictionary[int, TimedTask] = {} # [clip_id, Task]
var tasks: Array[Task] = []
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var error: int = -1



func _process(_delta: float) -> void:
	for i: int in timed_tasks.keys():
		if timed_tasks[i].check():
			timed_tasks[i].execute()
			timed_tasks.erase(i)

	mutex.lock()
	for i: int in range(tasks.size() - 1, -1, -1):
		var task: Task = tasks[i]
		if WorkerThreadPool.is_task_completed(task.id):
			error = WorkerThreadPool.wait_for_task_completion(task.id)
			if error:
				printerr("Threader: Error with task: ", task.id, " - Error: ", error)

			var next_task: Callable = task.after_task
			tasks.remove_at(i)
			mutex.unlock()
			if !next_task.is_null():
				next_task.call()
			mutex.lock()
	mutex.unlock()


func add_task(todo: Callable, after_todo: Callable = Callable()) -> void:
	var task: Task = Task.new(WorkerThreadPool.add_task(todo), after_todo)
	mutex.lock()
	tasks.append(task)
	mutex.unlock()


## Usefull for checking if a variable is being used by any thread, checking if
## videos are loaded or not is one of the use cases.
func check_tasks(value: Variant) -> bool:
	return tasks.any(_check_task.bind(value))


func _check_task(task: Task, value: Variant) -> bool:
	return task.after_task.get_bound_arguments().has(value)



class Task:
	var id: int = -1
	var after_task: Callable

	func _init(new_id: int, new_after_task: Callable = Callable()) -> void:
		id = new_id
		after_task = new_after_task



## Timed tasks are for items such as changing effects too quickly, instead of
## creating multiple tasks which cancel each other out with the last one, we
## keep updating the current task.
class TimedTask:
	var task: Callable
	var after_task: Callable
	var time: int

	func _init(new_task: Callable, new_after_task: Callable = Callable()) -> void:
		task = new_task
		after_task = new_after_task
		time = Time.get_ticks_msec() + 200

	func check() -> bool:
		return time <= Time.get_ticks_msec()

	func execute() -> void:
		Threader.tasks.append(Threader.Task.new(
				WorkerThreadPool.add_task(task), after_task))
