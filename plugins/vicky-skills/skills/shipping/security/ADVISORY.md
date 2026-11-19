# The advisory route

## The report file

`advisory.sh draft` reads a JSON file you write from the private report. Its public fields become the advisory:

| Field | Holds |
| --- | --- |
| `summary` | One line: what an attacker can do, never how. |
| `affected` | The affected range, such as `< 2.4.1`. |
| `fixed` | The fixed version, or `""` while the fix waits. |
| `cwe` | The weakness, such as `CWE-22`. |
| `cvss` | Your proposed CVSS 4.0 vector. The draft labels it CVSS-B, and the maintainer edits it in the draft. |
| `credit` | The reporter's name. Set `credit_declined: true` when they asked not to be named. |
| `fix_link` | The fix commit or pull request, once public. |

Its private fields never leave the machine: `run` (the proving run you wrote), `fp_check` (fp-check's verdict, `TRUE POSITIVE` or `FALSE POSITIVE`), `fix_branch`, `received` and `deadline` (both `YYYY-MM-DD`). With no deadline, the draft takes 90 days from `received`. Keep the reporter's steps and payload out of the file.

## Routes

- **github**: a repository advisory on the Security tab, a draft only maintainers see. The fix branch goes to the advisory's temporary private fork, never to origin. A CVE request goes to GitHub, which accepts one only for a public repo.
- **file**: the advisory text and an OSV 1.9.2 file in the plugin's data folder, one folder per repo, outside git. The fix stays on its local branch, unpushed. The CVE request is MITRE's web form, which the user sends. Publishing makes a release whose note is the advisory.
- **off**: the kit drafts nothing.

## Deadlines

The reporter's deadline is in the draft's own file. `advisory-deadline` names a draft at session start when its deadline is a week away and its fix has not shipped, and again once the deadline has passed while it is unpublished. An advisory publishes when the fix ships, or at the deadline, whichever comes first.
