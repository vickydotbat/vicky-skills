# Drafts: frontmatter-handoffs: retire G1 to G4

Press Done to send the text back.

## Retire G1, G3, G4 and the graph-file check
tests/skill_graph_approved_examples.test.sh:1
- [x] approve

```text
Delete tests/skill_graph_approved_examples.test.sh and the check <folder> <graph file> form of the skill graph.
H1 to H5 cover the same cases through each skill's hands-off field.
Delete text in this box to keep a part instead.
```

## G2 becomes a plain test
tests/skill_graph_approved_examples.test.sh:42
- [x] approve

```text
Given a skill that only names another skill without handing off to it, such as "do runs this skill"
When the plugin's tests run
Then they pass, with no hands-off field needed
```

## The plugin GRAPH.tsv check, already deleted
tests/skill_graph_approved_examples.test.sh:new
- [x] approve

```text
The check "the plugin's GRAPH.tsv matches its skills" stays deleted, since GRAPH.tsv is gone.
```
