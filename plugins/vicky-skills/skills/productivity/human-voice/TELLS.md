# The tell list

The sweep step walks this list top to bottom. Each entry gives the tell, the
fix, and where it helps a pair: a draft sentence, then the rewrite. The
user's own writing outranks every entry here, and Claude's metaphors are
listed in `SKILL.md`.

## Words and phrasing

- **Puffery** — *vibrant, rich tapestry, groundbreaking, cutting-edge,
  seamless, robust, holistic, intricate, multifaceted, dynamic, transformative,
  game-changer, pivotal, crucial, delve, dive into, underscore, testament,
  beacon, landscape, realm, journey, roadmap, myriad, plethora, leverage,
  harness, foster, unleash, unlock, empower, streamline, navigate, showcase,
  boasts, nestled, in the heart of, meticulous, comprehensive, paradigm shift,
  scalable*. Say the concrete thing: what it does, how fast, for whom.
  "The library provides a robust, comprehensive solution for handling dates"
  → "The library parses and formats dates, including time zones and leap
  seconds."
- **Significance talk** — *marks a pivotal moment, plays a vital role in,
  stands as a key part of, sets the stage for, shed light on, pave the way,
  this is where X really shines, the key takeaway is, it cannot be
  overstated*. State the fact and let the reader judge its size. "The 2.0
  release marks a pivotal moment" → "Version 2.0 dropped Node 16 support and
  cut the bundle by 40%."
- **Flattened judgment** — when the author has a view, write the view. "This
  ultimately led to the conclusion that prestige classes and subclasses served
  similar purposes" → "Prestige classes were just subclasses wearing a fancy
  hat."
- **Participle tails** — a clause hung on the end starting with
  *highlighting, underscoring, showcasing, reflecting, ensuring, contributing
  to, fostering*. Cut it, or promote it to its own sentence with a fact in it.
  "The cache stores results for an hour, significantly improving performance"
  → "The cache stores results for an hour. Repeat searches return in about
  20 ms instead of 400 ms."
- **Negative parallelism** — *not just X, but Y*; *it isn't X — it's Y*; *no
  X, no Y, just Z*. Say Y. "This isn't just a config file — it's the single
  source of truth" → "This config file is the source of truth for the whole
  deployment."
- **Adjective triads** — *fast, simple, and reliable*: three vague qualities
  where one measured fact would do. "The API is fast, flexible, and easy to
  use" → "The API answers in under 50 ms." A list of three real, distinct
  things is a list and stays: "less to review, less to break, and less
  cruft".
- **Dodging "is"** — *serves as, functions as, stands as, acts as,
  represents, boasts, features*. Use *is*, *are*, *has*.
- **Elegant variation** — a new synonym each time the same thing comes up
  (*limit*, then *threshold*, then *cap*). Repeat the one right word. The
  author's own odd word counts double: keep *crucible* if that is what they
  say.
- **Vague sourcing** — *experts argue, studies show, it is widely regarded,
  most people*. Say who, or cut the claim. Never invent the people.
  "Experts recommend rotating keys regularly" → "The OWASP cheat sheet
  recommends rotating keys every 90 days."
- **Vague links** — *in connection with, associated with, in relation to*.
  Say what the link is: *caused by*, *built on*, *replaced*.
- **Hedge stacks** — *may potentially help in some cases*, *it could be argued
  that*, *generally speaking*. Keep one qualifier, or commit. An open question
  in plain words is not a hedge and stays.
- **Vague antecedents** — an *it*, *that*, *this* or *them* the reader has
  to rebuild. Either the sentence never says the noun ("That could not be
  picked up"), or the pronoun reaches back past its sentence to stand for a
  whole idea, tucked into a tidy phrase like *every line of it*. The test is
  "...that what?": when a reader could ask it, write the noun. Point a pronoun
  only at the noun just before it, and repeat the noun when the pronoun would
  have to reach. "That is out of reach" → "This chest is out of reach."
  "Players spot AI writing on sight, and every line of it makes the server
  feel less like something people built" → "Players spot AI writing on
  sight. Every line an AI wrote makes the server feel less like something
  people built."
- **Sweep constructions** — *whether it's X or Y*, *from X to Y*, *ranging
  from X to Y*. Give the two or three real examples that matter.

## Claude's framing

- **Worth** — *worth noting, worth asking, worth considering, worth a look*. Say the thing.
- **Announced importance** — *this matters*, *here's the useful part*, *the
  most interesting part*. Drop the label and state the point.
- **Totalizing** — *that's the whole game*, *the only thing that matters*.
  Scale it to what is true.
- **Honesty tags** — *honestly*, *to be honest*, *I want to be careful here*.
  Cut them.
- **Added colour** — a quip, a vivid image or a dramatised reason hung on a
  plain rule, outside the showcase register. "A limit that froze you would let anyone pin
  you down by handing you rocks" → "A refusal never roots you in place,
  because anyone can give you an item without asking." "This one catches
  hoarders out" and "not only the ones swinging a greatsword" are the same
  tell. Count the asides on the page: more than one is the tell.
- **Coy phrasing** — an epigram, or a hint where the plain noun belongs.
  The reader has to decode it. Name the thing. "Every purse that stays at
  home is one a thief never lifts, so spending from the bank has a limit and
  costs you something your pocket doesn't" → "A thief can't lift your purse
  if you're not carrying it, so it has a fairly restrictive limit and costs
  an additional fee."
- **Quietly** — cut it unless something was really done without notice.
- **Drama words** — *settled* and *unsettled* for a decision, *wrecked* for a
  measured effect. Use the measured word: *open*, *decided*, *slowed by 20%*.
- **Consultant talk** — *pressure-test, north star, right-size, compounds,
  unpack, at the end of the day, lessons learned*. Use the plain verb.

## Layout of the piece

- **Formula openers** — *In today's fast-paced world*, *When it comes to*,
  *At its core*, *Picture this*. Open with the content.
- **Formula endings and joins** — *In conclusion*, *Overall*, *Ultimately*,
  *Furthermore*, *Moreover*, *Additionally*, *That being said*, *It is
  important to note*. Stop on the last real point. "Despite its simple design,
  the tool faces challenges. Overall, it remains a valuable addition" → "It
  has no Windows build yet." Then stop.
- **Hook lines** — *Here's the thing*, *But here's the kicker*, *Why does
  this matter?* followed by its own answer. Say the next fact. A hook the user
  writes in their own posts stays in their posts.
- **Talking about the writing** — *In this article we will explore*, *Let's
  dive in*, *I hope this helps*. Open with the content and stop when it ends.
- **Tidy progression** — three attempts rewritten as one inevitable path.
  Keep the order it happened in. "The design uses a single class table, which
  cleanly supports every archetype" → "One class table worked for a while.
  Then I built three classes with it and it fell apart, so the table now
  splits per archetype."
- **Even rhythm** — every paragraph three sentences, every sentence the same
  length. Vary length by cutting, not by joining: drop the echo, merge a fact
  with its own consequence, and let a short sentence end a point. Two
  independent facts stay two sentences.
- **Symmetry** — every section the same size, both sides given equal room, a
  summary at the end of each. Let the part the author cares about run long.
- **Quotable everything** — a metaphor or punchline in every paragraph, or a
  thesis restated at the end. "Character creation became a labyrinth of
  prompts, a tax form wearing a cloak" → "Character creation became a
  spreadsheet before you even start the game. Eleven prompts, and nine of them
  ask for numbers." Density is the tell, not the joke.
- **Reasons left out** — an explainer for players or users that is a string
  of true facts with no reason behind them. "Alignment is gone. You declare tenets
  instead." → name the vanilla rule, what changed, and why. This tell is for
  explainers and the showcase register: on a plain reference page, short
  facts and instructions are the target.
- **Placeholders** — leftover *[citation needed]*, *[TODO]*, citation debris
  like *turn0search0*. Fill them or drop the sentence.

## Formatting

- **Bold on key terms** — emphasis sprinkled over every important noun. Keep
  bold for the rare word that must not be missed, or the lead phrase of a
  rule in a list.
- **Heading case** — follow the surrounding document. Ask when there is
  none.
- **Inline-header bullets** — a wall of `- **Term**: one line` where the
  ideas connect. Write the paragraph. Keep bullets for items a reader will
  scan or come back to: rules, flags, options, steps.
- **Numbered everything** — sections numbered for the sake of it, *three
  things to know*, *key takeaways*. Number only a real sequence.
- **Tables and emoji as decoration** — tables hold data with real columns.
  Emoji stay out unless the house style uses them.
- **Em dash flood** and **horizontal rules before every heading** — one spaced
  dash pair per paragraph reads as a person. Three is the tell.
- **Curly quotes and stray Markdown** — straight quotes, and formatting that
  matches the target format (Markdown, wiki HTML, plain text, code comment).
