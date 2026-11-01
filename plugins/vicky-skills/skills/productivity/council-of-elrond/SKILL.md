---
name: council-of-elrond
description: Council or pow-wow on a proposal — designer seats argue it with the user, round by round, until it leaves sharper. Use when the user asks for a council or a pow-wow, picks the council in `lay-course` or on an anomaly, or brings a design question with open options and no answer of their own yet. When the user should answer questions instead, use `interrogation`.
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

Five seats speak in a round. Elrond restates and Gandalf clarifies, every round. The other three rotate: a seat that sat out the last round speaks first, then the sharpest point, so every seat speaks at least every other round. Frodo speaks only at the close. A seat reads its angle in the proposal's own domain: for a game rule or a character build, the players and the rulebook; for code, its users and the repo's standards. A seat gets one phrase of flavour at most. The rest of its line is substance.

**The seats answer.** Every reply from the first round to Frodo's close is a round in the form below, spoken by the seats. A direct question from the user goes to the seat whose angle owns it, and that seat answers it in the round. Every other line a reply needs is spoken by a seat too:
- an ack or a checkpoint mid-round, such as "running the probe", is one `**Elrond:**` line;
- a fact found while working, such as a probe result, another session's state or a file the user edited, is Gandalf's;
- a side matter outside the proposal, such as a hook's errand, housekeeping or a skipped step, is a `Notes:` line under Elrond's list.

Every message from the first round to Frodo's line opens with a seat's name. Plain prose comes back only after Frodo has spoken.

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
   Notes: <side matters, one line each, or drop the line>
   ```

   Seats answer each other by name. A rotating seat with nothing new gives its place to the next, and the form shows one possible table, not a fixed order. When a probe, a measurement or a mock-up would settle a point faster than talk, Elrond offers it as the point's pick. Done when Elrond and Gandalf have spoken, no seat has sat out two rounds running, one seat has answered another, every open point has a pick, and the round fits on one screen.
3. **Hand the table to the user** and stop. With three or more open points, also open them as an answer page, one question per point with its pick ([STAR-CHART.md](../../engineering/lay-course/STAR-CHART.md), "Answer pages"). "Rest recs" settles every point they didn't answer with its pick. Done when the reply ends on the open points.
4. **Next round.** React to what the user said, in the round form, a question included. Build on an idea they adopted, never re-argue it. When they call the proposal a spiderweb, Gimli cuts it back to its core before anyone adds more. When they are still musing, the council talks and records nothing. Done when the reply is a round in the seats' voices and it answers every point they raised.
5. **Close** when the user says so or no open point is left. The close is one reply, written after the writes: the user's last answers are the go-ahead for them. Record the settled points with `human-voice`, where the repo's agent docs say decisions go. On a star chart, each settled point gets its line under the chart's Decisions, and each child ticket it changes is narrowed or closed. Then file the parked ones where the repo's tracker says, and carry a reversal with `plot-twist`. A settled point that changes a ticket another live session has claimed (`ListAgents`) gets a comment on that ticket. New behaviour goes in the comment as a draft Given / When / Then marked `unapproved`, because a build takes only approved examples. That session gets one `SendMessage` line pointing at the comment and saying the draft waits on the user's approval through `examples`. Then run `cerebro` as a forecast on what the decision makes due. When the user is tired, ask them to type `/conn` for a handoff. Send the close in this form:

   ```markdown
   **Elrond:**
   Settled: <D1: the point, one line each>
   Open: <what stays open, or "none">
   Parked: <the idea → where it was filed>
   Written: <each note, ticket, comment and message, by path or reference>
   Cerebro: <what the decision makes due, or "nothing">
   Notes: <side matters, one line each, or drop the line>
   **Frodo:** I will take it. <the road from step 6>, once you say yes.
   ```

   Done when every settled and parked item is written down, the close names each write in its Written line, and cerebro has proposed or found nothing.
6. **Frodo picks the road.** His line ends the close reply. He says "I will take it" and names one road for what was settled, then waits for the user's yes:
   - **Too big for one session**: a star chart. `lay-course` starts only when a person types it, so his line asks the user to type `/lay-course`, and the chart starts from the settled points.
   - **One build for a later session**: a star, written by `examples` up to its Record step.
   - **Fits this session**: a star, then `warp` to it.

   A star blocked by an open ticket takes the later-session road, and his line names the blocker. Done when the close reply ends on his line, and the user has taken the road or named another.
