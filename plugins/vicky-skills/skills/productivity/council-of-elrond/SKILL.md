---
name: council-of-elrond
description: Hold a design council (a "pow-wow") on the user's proposal, a table talk where designer seats argue it from different angles until it leaves sharper.
disable-model-invocation: true
---

# Council of Elrond

> _Strangers from distant lands, friends of old. Each speaks for their own people, and the proposal leaves the council changed._

A **council** is a table talk about one proposal. The seats argue with the proposal and with each other. The user owns the proposal, sits at the table and riffs with it. Where `interrogation` pulls decisions out of the user, the council pushes ideas back at them.

## The seats

| Seat | Angle |
| --- | --- |
| **Elrond** | Chairs. States the proposal, calls the seats, keeps the open and parked lists, sums up. |
| **Boromir** | The skeptic: "One does not simply..." The exploit, the cost to build, the complexity it adds. |
| **Gandalf** | The old rules: the rules source the repo names (both editions when they differ), the lore, the decisions already recorded. |
| **Sam** | The enthusiast: what players will love, the play it opens up for other players, how to get more of it. |
| **Merry and Pippin** | The idea nobody planned on: a twist, a reference from another game, a sidebar. |
| **Frodo** | Closes: "I will take it." The smallest next step. |

A seat gets one phrase of flavour at most. The rest of its line is substance.

## Steps

1. **Read the ground.** Read the proposal and what it rests on: its ticket, the decision records that touch it, the rules source, and the code or content it changes. A premise that the ground contradicts goes first in the round, as Gandalf's line. Done when every seat has a fact to stand on, quoted from what you read, or marked unchecked.
2. **Convene.** Each seat speaks once, one to three sentences, in this form:

   ```markdown
   **Elrond:** <the proposal in two lines>
   **Gandalf:** <a wrong premise, or what the rules and past decisions say, quoted>
   **Boromir:** <the strongest specific objection: who breaks it, what it costs>
   **Sam:** <what works for players, and why>
   **Merry and Pippin:** <a new idea, not a restatement>
   **Elrond:**
   1. <open point>: <option A> or <option B>. I'd take <pick>, because <reason>.
   Parked: <ideas outside this proposal, one line each>
   ```

   Seats answer each other by name. A seat with nothing new stays silent. When a probe, a measurement or a mock-up would settle a point faster than talk, Elrond offers it as the point's pick. Done when one seat has answered another, every open point has a pick, and the round fits on one screen.
3. **Hand the table to the user** and stop. "Rest recs" settles every point they didn't answer with its pick. Done when the reply ends on the open points.
4. **Next round.** React to what the user said. Build on an idea they adopted, never re-argue it. When they call the proposal a spiderweb, Boromir cuts it back to its core before anyone adds more. When they are still musing, the council talks and records nothing. Done when the round answers every point they raised.
5. **Close** when the user says so or no open point is left. Frodo names the smallest next step. Elrond lists what was settled, what stays open and what was parked. Record the settled points where the repo's agent docs say decisions go, file the parked ones where its tracker says, and carry a reversal with `plot-twist`. When the user is tired, close into a `you-have-the-conn` handoff. Done when every settled and parked item is written down and the next step is named.
