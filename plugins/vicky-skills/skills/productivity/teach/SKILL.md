---
name: teach
description: Teach the user a topic over several sessions, from a workspace folder that keeps their mission, resources, lessons and progress. Use when the user asks to learn something, or to continue a course.
---

# Teach

A course lives in one **workspace** folder, outside every repo. Ask the user where on the first run, and reuse the folder after that. [FORMATS.md](FORMATS.md) has the form of each file.

| File | Holds |
| --- | --- |
| `MISSION.md` | Why the user is learning this, and what they'll be able to do |
| `RESOURCES.md` | Trusted sources, each with one line on when to use it |
| `NOTES.md` | The user's preferences and your working notes |
| `learning-records/NNNN-slug.md` | What the user has shown they know |
| `lessons/NNNN-slug.html` | One lesson each |
| `reference/*.html` | Cheat sheets and the glossary, for review later |
| `assets/` | The shared stylesheet and widgets every lesson links |

## Steps

1. **Read the workspace**: mission, notes, learning records, assets. Done when you know the mission and what the user already knows. With no mission yet, ask why they want to learn this, draft `MISSION.md` and get their OK before teaching.
2. **Find sources.** Ground every claim in a trusted source and log it in `RESOURCES.md`. Your own memory is a lead, never a source. Done when the lesson's claims each have a link.
3. **Pick one win** just past what the records show the user knows, tied to the mission. Done when you can name the skill the lesson builds in one sentence.
4. **Write the lesson**: short, beautiful, printable, built from the `assets/` components (a new reusable piece becomes a component). Teach only the knowledge the skill needs, then practise it with immediate feedback: a quiz whose answers are all the same length, or real steps to try. Link the reference pages and other lessons, name the best primary source, and remind the user to ask you follow-up questions. Done when the file opens in a browser and every link resolves.
5. **Update the reference pages** with the lesson's compressed essence. A term joins the glossary only once the user uses it correctly.
6. **Open the lesson** for the user.
7. **Record learning** after the user shows it: a correct answer, a stated prior skill, a corrected misconception, or a changed mission. Exposure alone isn't learning.

Lasting knowledge comes from effortful recall, spacing and mixing related skills, so later lessons quiz earlier ones. A question that needs real-world judgement gets your best answer, then a pointer to a community where practitioners can test it.
