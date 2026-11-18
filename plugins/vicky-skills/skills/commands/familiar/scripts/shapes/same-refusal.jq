# A refused tool call run again unchanged: prints the timestamp of each repeat.
# Input: one transcript, slurped. Frozen: change a rule only with a new name.
[.[] | select(.type == "assistant") | .timestamp as $t | .message.content[]? | select(.type == "tool_use") | {id, name, input, t: $t}] as $uses
| [.[] | select(.type == "user") | .message.content[]? | select(.type == "tool_result" and .is_error == true)
   | select((.content | tostring) | test("hook error")) | .tool_use_id] as $refused
| range(1; $uses | length) as $i
| select(any($refused[]; . == $uses[$i - 1].id) and $uses[$i].name == $uses[$i - 1].name and $uses[$i].input == $uses[$i - 1].input)
| $uses[$i].t
