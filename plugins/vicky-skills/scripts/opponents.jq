# Shared by the opponent hooks: which deathmatch opponents still fight.
# Include it with jq -L <scripts folder> 'include "opponents"; ...'.

# The opponent launches the transcript records hold, as {id, type}.
def opponent_launches($r):
  [$r[] | select(.type == "assistant") | .message.content[]? | objects
   | select(.type == "tool_use" and (.name == "Agent" or .name == "Task")
            and ((.input.subagent_type // "") | endswith("opponent")))
   | {id, type: .input.subagent_type}];

# Each launch in $launches ({id, ...}) still fighting, with its agent id added
# as .agent (null before its receipt lands). A launch is done when its result
# is an error, its agent was stopped with TaskStop, or its last task
# notification says it finished and no message was sent to it after that. An
# interim notification, one that says it waits on its own background work,
# leaves it fighting.
def fighting($r; $launches):
  [$r[] | select(.type == "user") | .message.content[]? | objects
   | select(.type == "tool_result" and .is_error == true) | .tool_use_id] as $errors
  | [$r[] | select((.toolUseResult | type) == "object" and .toolUseResult.agentId != null)
     | {id: (.message.content[0].tool_use_id // ""), agent: .toolUseResult.agentId}] as $agents
  | [range(0; $r | length) as $i | $r[$i] | [.. | strings | select(contains("<task-notification>"))][]
     | {i: $i, t: .}] as $notes
  | [range(0; $r | length) as $i | $r[$i] | select(.type == "assistant") | .message.content[]? | objects
     | select(.type == "tool_use" and .name == "SendMessage") | {i: $i, to: (.input.to // "")}] as $sends
  | [$r[] | select(.type == "assistant") | .message.content[]? | objects
     | select(.type == "tool_use" and .name == "TaskStop") | (.input.task_id // .input.shell_id // "")] as $stops
  | $launches[] | . as $l
  | select(($errors | index($l.id)) | not)
  | ([$agents[] | select(.id == $l.id) | .agent] | first) as $a
  | select($a == null or (($stops | index($a)) | not))
  | ([$notes[] | select((.t | contains("<tool-use-id>" + $l.id + "</tool-use-id>"))
                        or ($a != null and (.t | contains("<task-id>" + $a + "</task-id>"))))] | last) as $n
  | ([$sends[] | select($a != null and .to == $a) | .i] | max) as $s
  | select($n == null or ($n.t | contains("waiting on its own background work")) or ($s != null and $s > $n.i))
  | $l + {agent: $a};
