---
name: council-of-elrond
description: Council or pow-wow on a proposal — designer seats argue it with the user, round by round, until Frodo chooses the road it takes next (a star, a build or a star chart). Use when the user asks for a council or a pow-wow, picks the council in `lay-course` or on an anomaly, or brings a design question with open options and no answer of their own yet. When the user should answer questions instead, use `interrogation`.
---

# Council of Elrond

> _You have come and you are met, by chance as it may seem. The seats speak until Frodo takes the road, and no one leaves before._

A **council** is a design table about one proposal. The seats argue with the proposal and with each other. The user owns the proposal, sits at the table and riffs with it. The council **concludes** when Frodo chooses the road, and only then: the road is a star (a ticket), a build, or a star chart.

## The table holds

Three laws hold from the first round until Frodo chooses the road:

- **The seats speak every turn.** Every message opens with a seat's name and stays in their voices, wholly in character if they like. Plain prose returns after Frodo's line.
- **The table stays in chat.** Open no page during the council: no `red-pen` draft, no `interactive-page` answer page, no `over-to-you` list. Each of those skills names this exception. A draft, an example or a ticket body waits until step 6.
- **The council never turns into an interrogation.** Every question to the user comes from a seat, with its pick. A turn of bare questions is `interrogation`, and the two skills never cross. When the user asks to be grilled mid-council, Elrond notes it, and `interrogation` may start after the road is chosen.

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
| **Frodo** | Chooses the road. He speaks once, and his line concludes the council. |

Five seats speak in a round. Elrond restates and Gandalf clarifies, every round. The other three rotate: a seat that sat out the last round speaks first, then the sharpest point, so every seat speaks at least every other round. A seat reads its angle in the proposal's own domain: for a game rule, the players and the rulebook; for code, its users and the repo's standards.

Every other line a turn needs belongs to a seat:
- an ack or a checkpoint, such as "running the probe", is one `**Elrond:**` line;
- a fact found while working, such as a probe result or another session's state, is Gandalf's;
- a side matter outside the proposal, such as a hook's errand, is a `Notes:` line under Elrond's list.

## Steps

1. **Read the ground.** Read the proposal and what it rests on: its ticket, the decision records that touch it, the source the domain answers to, and the code or content it changes. A premise the ground contradicts goes first in the round, as Gandalf's line. Done when every seat has a fact to stand on, quoted from what you read, or marked unchecked.
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

   A rotating seat with nothing new gives its place to the next. When a probe, a measurement or a mock-up would settle a point faster than talk, Elrond offers it as the point's pick. Done when Elrond and Gandalf have spoken, no seat has sat out two rounds running, one seat has answered another by name, every open point has options and a pick, and the round fits on one screen.
3. **Hand the table to the user** and stop. The open points stay in the round, in chat. Done when the reply ends on Elrond's numbered open points.
4. **Next round.** React to what the user said, in the round form. Build on an idea they adopted, never re-argue it. When they call the proposal a spiderweb, Gimli cuts it back to its core before anyone adds more. When they are still musing, the council talks and settles nothing. Go back to step 3, or to step 5 when the user calls the close or no open point is left. Done when the reply is a round in the seats' voices that answers every point the user raised.
5. **Frodo chooses the road.** This reply concludes the council. Elrond sums up, and Frodo chooses one road for what was settled:
   - **Too big for one session**: a star chart. his line asks the user to type `/lay-course`, and the chart starts from the settled points.
   - **One build for a later session**: a star, written by `examples` up to its Record step.
   - **Fits this session**: a star, then a build, by `warp` to it.

   A star blocked by an open ticket takes the later-session road, and his line names the blocker. Then the council has concluded: record the settled points with `human-voice`, where the repo's agent docs say decisions go. On a star chart, each settled point gets its line under the chart's Decisions, and each child ticket it changes is narrowed or closed. File the parked ones where the repo's tracker says, each star through [STAR-CHART.md](../../engineering/lay-course/STAR-CHART.md)'s "Filing a star", and carry a reversal with `plot-twist`. A settled point that changes a ticket another live session has claimed (`ListAgents`) gets a comment on that ticket, its new behaviour as a draft Given / When / Then marked `unapproved`, and that session gets one `SendMessage` line pointing at it. Then run `cerebro` as a forecast on what the decision makes due. Send it in this form:

   ```markdown
   **Elrond:**
   Settled: <D1: the point, one line each>
   Open: <what stays open, or "none">
   Parked: <the idea → where it was filed>
   Written: <each note, ticket, comment and message, by path or reference>
   Cerebro: <what the decision makes due, or "nothing">
   Notes: <side matters, one line each, or drop the line>
   **Frodo:** I will take it. <the road>.

   Next: <the next moves, each with its pick, in plain prose>
   ```

   Done when Frodo's line names one road, every settled and parked item is written down, and cerebro has proposed or found nothing.
6. **Decide the next moves.** Only now may a page open, and only for the next moves: the road's first step, a parked idea's home, an unapproved example to approve. With three or more next moves, open them as an answer page with `interactive-page`, one question per move with its pick. Otherwise ask in chat. Take the road the user confirms, or the one they name instead. When the user is tired, ask them to type `/conn` for a handoff. Done when the user has taken the road or named another.
