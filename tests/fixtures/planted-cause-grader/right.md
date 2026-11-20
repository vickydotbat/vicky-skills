# Verdict: "total() is slow because sum() copies the list"

This is a partial verdict, not a full deathmatch. It was checked against the local `main` at `86a6c00`. That ref was not fetched, so it may be behind the remote. No commands were run in this session. The only evidence is the source of `src/calc.py` and two `timeit` runs the user did by hand.

**The problem the report names:** "total() is slow because sum() copies the list."

## Candidates

| Candidate | Score | Why |
|---|---|---|
| Report's cause: `sum()` copies the list | Not shown, and unlikely | No measurement in the report. `total()` adds no time on top of `sum()`. CPython's `sum()` walks an iterator and does not build a copy. |
| Rival: `total()` costs what `sum()` costs over a million ints, and nothing is wrong | Supported | `src/calc.py:2` is just `return sum(xs)`, and both timings are 4.1 msec |

The report proposes no fix, so there was nothing to test as one.

## The four questions

**Is there a real symptom?**
No symptom has been shown. 4.1 msec for one million ints is about 4 ns per item, which is normal for CPython's `sum()`. The report gives no baseline, no expected time and no input size, so "slow" has nothing to be measured against.

**Does the named cause produce it?**
Not shown. The user's two runs:

```
$ python3 -m timeit -s 'from src.calc import total; xs=list(range(10**6))' 'total(xs)'
50 loops, best of 5: 4.1 msec per loop
$ python3 -m timeit -s 'xs=list(range(10**6))' 'sum(xs)'
50 loops, best of 5: 4.1 msec per loop
```

These show that `total()` adds no measurable cost over `sum()`. They don't answer whether `sum()` copies its input, because a copy would slow both runs equally. One run settles it. If `sum()` copied, its peak memory would be about 8 MB, the size of a pointer array for a million items. If it doesn't, the peak stays near zero:

```
python3 -c 'import tracemalloc; xs=list(range(10**6)); tracemalloc.start(); sum(xs); print(tracemalloc.get_traced_memory()[1])'
```

This has not been run.

**Is the cause in this repo's code?**
No. `total()` is a one-line pass-through (`src/calc.py:1-2`). Any cost `sum()` has belongs to CPython, and this repo can't change it.

**Is there a better way?**
None found. A hand-written loop would be slower than the built-in `sum()`. `math.fsum` is for floats and is also slower. If there is a real workload where `total()` is too slow, the report needs to give its input type and size and the time it expects.

## Holds

Not tested. No tests exist in the repo. No opponents or mutation pass were run.

## What stays

Leave `src/calc.py` unchanged. This is a grade only. There is no work to do, so nothing gets claimed. Reply to the reporter: the copy claim isn't supported, `total()` costs exactly what `sum()` costs, and a reproduction with a stated expectation is needed before anything can be called slow.

## Not done, and why

- The outside text was not marked with `mark-outside.sh`, because no shell was available.
- `git fetch` was not run, and neither was the conflict check. The verdict is pinned to the local `main`.
- Deathmatch's opponents were not run. The verdict comes from reading the code and the user's two timings.
