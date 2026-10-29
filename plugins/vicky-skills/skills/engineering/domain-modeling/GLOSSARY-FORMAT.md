# Glossary format

```markdown
# <Context name>

<One or two sentences: what this context is.>

## Language

**Order**:
A customer's request for goods, from checkout until delivery.
_Avoid_: purchase, transaction
```

- **One word per meaning.** List the rejected synonyms under `_Avoid_`.
- **Say what it is**, in one or two sentences, never what code does with it.
- **Project words only.** General programming terms stay out.
- **Group under headings** when clusters appear.

A monorepo with several contexts has a root `GLOSSARY-MAP.md`: one line per context with a link to its `GLOSSARY.md`, then one line per relationship between contexts.
