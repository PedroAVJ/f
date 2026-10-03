import Base

# Pure lifecycle shared by every assistant surface. Effects belong to adapters.
type Phase is Data:
  Idle{}
  Running{}
  Cancelled{}
  Failed{}
type Call is Data:
  Closed{}
  Active{}
type Permission is Data:
  Denied{}
  Granted{}
type TaskApproval is Data:
  NoApprovalNeeded{}
  AwaitingApproval{}
  ExecutionApproved{}
  ExecutionRejected{}
type Session is Data:
  Session{revision: U32, phase: Phase, call: Call, microphone: Permission}
type Command is Data:
  Start{}
  Finish{}
  Cancel{}
  RunFailed{}
  GrantMic{}
  DenyMic{}
  BeginCall{}
  EndCall{}

def initial() -> Session:
  Session{0, Idle{}, Closed{}, Denied{}}

def update(event: Command, session: Session) -> Session:
  match event session:
    case Start{} Session{+r, p, c, m}: Session{(r + 1 : U32), Running{}, c, m}
    case Finish{} Session{+r, p, c, m}: Session{(r + 1 : U32), Idle{}, c, m}
    case Cancel{} Session{+r, p, c, m}: Session{(r + 1 : U32), Cancelled{}, c, m}
    case RunFailed{} Session{+r, p, c, m}: Session{(r + 1 : U32), Failed{}, c, m}
    case GrantMic{} Session{+r, p, c, m}: Session{(r + 1 : U32), p, c, Granted{}}
    case DenyMic{} Session{+r, p, c, m}: Session{(r + 1 : U32), p, Closed{}, Denied{}}
    case BeginCall{} Session{+r, p, c, Granted{}}: Session{(r + 1 : U32), p, Active{}, Granted{}}
    case BeginCall{} Session{r, p, c, Denied{}}: Session{r, p, c, Denied{}}
    case EndCall{} Session{+r, p, c, m}: Session{(r + 1 : U32), p, Closed{}, m}

def phase(s: Session) -> String:
  match s:
    case Session{r, Idle{}, c, m}: "idle"
    case Session{r, Running{}, c, m}: "running"
    case Session{r, Cancelled{}, c, m}: "cancelled"
    case Session{r, Failed{}, c, m}: "failed"

def in_call(s: Session) -> Bool:
  match s:
    case Session{r, p, Active{}, m}: True{}
    case Session{r, p, Closed{}, m}: False{}

def task_permitted(approval: TaskApproval) -> Bool:
  match approval:
    case NoApprovalNeeded{}: True{}
    case ExecutionApproved{}: True{}
    case AwaitingApproval{}: False{}
    case ExecutionRejected{}: False{}

# Conversation and task data are pure typed state. Host adapters only own IO.
type MessageRole is Data:
  UserMessage{}
  AssistantMessage{}
type MessageSource is Data:
  ChatMessage{}
  CallMessage{}
type MessageStatus is Data:
  UserRecorded{}
  StreamingMessage{}
  CompleteMessage{}
  CancelledMessage{}
  FailedMessage{}
  FragmentMessage{}
type Message is Data:
  Message{id: String, role: MessageRole, source: MessageSource, text: String, status: MessageStatus}
type TextEvent is Data:
  TextDelta{text: String}
  TextResult{text: String}
  TextError{message: String}
  TextCancelled{}
type TaskStatus is Data:
  TaskReady{}
  TaskRunning{}
  TaskDone{}
  TaskFailed{}
  TaskCancelled{}
type Task is Data:
  Task{id: String, title: String, status: TaskStatus, approval: TaskApproval, result: String, error: String}
type TaskEvent is Data:
  ApproveTask{}
  RejectTask{}
  StartTask{}
  FinishTask{result: String}
  FailTask{message: String}
  CancelTask{}
  RestoreTask{}
type Continuity is Data:
  Continuity{messages: List<&2, Message>, tasks: List<&2, Task>}

def history_initial() -> Continuity:
  Continuity{[], []}

def append_message(xs: List<&2, Message>, message: Message) -> List<&2, Message>:
  match xs:
    case Nil{}: [message]
    case Con{head, tail}: Con{head, append_message(tail, message)}

def append_task(xs: List<&2, Task>, task: Task) -> List<&2, Task>:
  match xs:
    case Nil{}: [task]
    case Con{head, tail}: Con{head, append_task(tail, task)}

def history_message(message: Message, history: Continuity) -> Continuity:
  match history:
    case Continuity{messages, tasks}: Continuity{append_message(messages, message), tasks}

def history_task(task: Task, history: Continuity) -> Continuity:
  match history:
    case Continuity{messages, tasks}: Continuity{messages, append_task(tasks, task)}

# A terminal result closes a stream. Late events leave terminal records intact.
def reduce_text(event: TextEvent, +message: Message) -> Message:
  match event message:
    case TextDelta{delta} Message{id, role, source, text, StreamingMessage{}}: Message{id, role, source, text ++ delta, StreamingMessage{}}
    case TextResult{result} Message{id, role, source, text, StreamingMessage{}}: Message{id, role, source, result, CompleteMessage{}}
    case TextError{error} Message{id, role, source, text, StreamingMessage{}}: Message{id, role, source, text, FailedMessage{}}
    case TextCancelled{} Message{id, role, source, text, StreamingMessage{}}: Message{id, role, source, text, CancelledMessage{}}
    case _ _: message

def reduce_task(event: TaskEvent, +task: Task) -> Task:
  match event task:
    case ApproveTask{} Task{id, title, status, AwaitingApproval{}, result, error}: Task{id, title, status, ExecutionApproved{}, result, error}
    case RejectTask{} Task{id, title, status, AwaitingApproval{}, result, error}: Task{id, title, TaskCancelled{}, ExecutionRejected{}, result, error}
    case StartTask{} Task{id, title, TaskReady{}, +approval, result, error}:
      Bool.pick(Task, task_permitted(approval), Task{id, title, TaskRunning{}, approval, result, error}, Task{id, title, TaskReady{}, approval, result, error})
    case FinishTask{result} Task{id, title, TaskRunning{}, approval, old, error}: Task{id, title, TaskDone{}, approval, result, ""}
    case FinishTask{result} Task{id, title, TaskReady{}, +approval, old, error}:
      Bool.pick(Task, task_permitted(approval), Task{id, title, TaskDone{}, approval, result, ""}, Task{id, title, TaskReady{}, approval, old, error})
    case FailTask{error} Task{id, title, TaskRunning{}, approval, result, old}: Task{id, title, TaskFailed{}, approval, result, error}
    case CancelTask{} Task{id, title, TaskDone{}, approval, result, error}: Task{id, title, TaskDone{}, approval, result, error}
    case CancelTask{} Task{id, title, status, approval, result, error}: Task{id, title, TaskCancelled{}, approval, result, error}
    case RestoreTask{} Task{id, title, TaskRunning{}, ExecutionApproved{}, result, error}: Task{id, title, TaskReady{}, AwaitingApproval{}, result, error}
    case RestoreTask{} Task{id, title, TaskRunning{}, approval, result, error}: Task{id, title, TaskReady{}, approval, result, error}
    case RestoreTask{} Task{id, title, TaskDone{}, approval, result, error}: Task{id, title, TaskDone{}, approval, result, error}
    case RestoreTask{} Task{id, title, status, ExecutionApproved{}, result, error}: Task{id, title, status, AwaitingApproval{}, result, error}
    case _ _: task

type Permissions is Data:
  Permissions{microphone: Permission, persistence: Permission}
type PermissionCommand is Data:
  PermitMicrophone{}
  RevokeMicrophone{}
  PermitPersistence{}
  RevokePersistence{}

def permissions_initial() -> Permissions:
  Permissions{Denied{}, Denied{}}

def reduce_permissions(event: PermissionCommand, permissions: Permissions) -> Permissions:
  match event permissions:
    case PermitMicrophone{} Permissions{mic, persistence}: Permissions{Granted{}, persistence}
    case RevokeMicrophone{} Permissions{mic, persistence}: Permissions{Denied{}, persistence}
    case PermitPersistence{} Permissions{mic, persistence}: Permissions{mic, Granted{}}
    case RevokePersistence{} Permissions{mic, persistence}: Permissions{mic, Denied{}}

def permission_granted(permission: Permission) -> Bool:
  match permission:
    case Granted{}: True{}
    case Denied{}: False{}

def call_record_permitted(session: Session) -> Bool:
  match session:
    case Session{r, Cancelled{}, c, m}: False{}
    case Session{r, p, Active{}, Granted{}}: True{}
    case _: False{}

# Source authorization also lives at the pure history boundary.
def history_record(session: Session, +message: Message, +history: Continuity) -> Continuity:
  match message:
    case Message{id, role, ChatMessage{}, text, status}: history_message(Message{id, role, ChatMessage{}, text, status}, history)
    case Message{id, role, CallMessage{}, text, status}:
      Bool.pick(Continuity, call_record_permitted(session), history_message(Message{id, role, CallMessage{}, text, status}, history), history)

def new_task(id: String, title: String, requires_approval: Bool) -> Task:
  Task{id, title, TaskReady{}, Bool.pick(TaskApproval, requires_approval, AwaitingApproval{}, NoApprovalNeeded{}), "", ""}

def message_id(message: Message) -> String:
  match message:
    case Message{id, role, source, text, status}: id

def task_id(task: Task) -> String:
  match task:
    case Task{id, title, status, approval, result, error}: id

def reduce_messages(+event: TextEvent, +id: String, messages: List<&2, Message>) -> List<&2, Message>:
  match messages:
    case Nil{}: []
    case Con{+head, tail}:
      Con{Bool.pick(Message, String.eq(message_id(head), id), reduce_text(event, head), head), reduce_messages(event, id, tail)}

def reduce_tasks(+event: TaskEvent, +id: String, tasks: List<&2, Task>) -> List<&2, Task>:
  match tasks:
    case Nil{}: []
    case Con{+head, tail}:
      Con{Bool.pick(Task, String.eq(task_id(head), id), reduce_task(event, head), head), reduce_tasks(event, id, tail)}

def history_text(event: TextEvent, id: String, history: Continuity) -> Continuity:
  match history:
    case Continuity{messages, tasks}: Continuity{reduce_messages(event, id, messages), tasks}

def history_task_event(event: TaskEvent, id: String, history: Continuity) -> Continuity:
  match history:
    case Continuity{messages, tasks}: Continuity{messages, reduce_tasks(event, id, tasks)}
