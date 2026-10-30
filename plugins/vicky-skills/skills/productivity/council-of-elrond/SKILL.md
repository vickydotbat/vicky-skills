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
| **Boromir** | The skeptic: "One does not simply..." How it breaks or gets abused, and what it costs to build. |
| **Gimli** | The axe: is it worth building at all? He swings at every part, and what survives the swing is the core. |
| **Legolas** | The far sight: how it fits the rest of the system, and how it holds at scale or six months on. He and Gimli rarely agree. |
| **Aragorn** | The ranger among the people: he walks through it step by step as the person using it, in the moment they use it. |
| **Gandalf** | The old rules: the source the domain answers to (a rulebook, a spec, a standard, the lore), both editions when they differ, and the decisions already recorded. |
| **Sam** | The enthusiast: what the people who use it will love, what it opens up for them, how to get more of it. |
| **Merry and Pippin** | The idea nobody planned on: a twist, a reference from elsewhere, a sidebar. |
| **Frodo** | Closes: "I will take it." The road the result takes next. |

At most five seats speak in a round: Elrond, then the ones with the sharpest point. A seat reads its angle in the proposal's own domain: for a game rule or a character build, the players and the rulebook; for code, its users and the repo's standards. A seat gets one phrase of flavour at most. The rest of its line is substance.

## Steps

1. **Read the ground.** Read the proposal and what it rests on: its ticket, the decision records that touch it, the source the domain answers to, and the code or content it changes. A premise that the ground contradicts goes first in the round, as Gandalf's line. Done when every seat has a fact to stand on, quoted from what you read, or marked unchecked.
2. **Convene.** Each seat speaks once, one to three sentences, in this form:

   ```markdown
   **Elrond:** <the proposal in two lines>
   **Gandalf:** <a wrong premise, or what the rules and past decisions say, quoted>
   **Boromir:** <the strongest specific objection: who breaks it, what it costs>
   **Gimli:** <the part to cut, and the core that survives>
   **Sam:** <what works for the people who use it, and why>
   **Merry and Pippin:** <a new idea, not a restatement>
   **Elrond:**
   1. <open point>: <option A> or <option B>. I'd take <pick>, because <reason>.
   Parked: <ideas outside this proposal, one line each>
   ```

   Seats answer each other by name. A seat with nothing new stays silent, and the form shows one possible table, not a fixed order. When a probe, a measurement or a mock-up would settle a point faster than talk, Elrond offers it as the point's pick. Done when one seat has answered another, every open point has a pick, and the round fits on one screen.
3. **Hand the table to the user** and stop. "Rest recs" settles every point they didn't answer with its pick. Done when the reply ends on the open points.
4. **Next round.** React to what the user said. Build on an idea they adopted, never re-argue it. When they call the proposal a spiderweb, Gimli cuts it back to its core before anyone adds more. When they are still musing, the council talks and records nothing. Done when the round answers every point they raised.
5. **Close** when the user says so or no open point is left. Elrond lists what was settled, what stays open and what was parked. Record the settled points where the repo's agent docs say decisions go, file the parked ones where its tracker says, and carry a reversal with `plot-twist`. When the user is tired, close into a `you-have-the-conn` handoff. Done when every settled and parked item is written down.
6. **Frodo picks the road.** He says "I will take it" and names one road for what was settled, then waits for the user's yes:
   - **Too big for one session**: a map. `lay-course` starts only when a person types it, so his line asks the user to type `/lay-course`, and the map starts from the settled points.
   - **One build for a later session**: a build ticket, written by `examples` up to its Record step.
   - **Fits this session**: `examples`, then `do`.

   Done when the user has taken the road or named another.
