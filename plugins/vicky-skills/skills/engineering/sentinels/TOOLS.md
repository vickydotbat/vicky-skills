# Mutation tools by ecosystem

Use these when the repo names no tool. Run each one without a global install. Before the first run, read its `--help` for two flags: the one that limits the files or lines it mutates, and the one that sets how many workers run at once. Set workers to 1 under a memory cap and raise them only after a measured run.

| Ecosystem | Tool | Run it with |
| --- | --- | --- |
| .NET | Stryker.NET | `dotnet tool install dotnet-stryker` into the repo's tool manifest, then `dotnet stryker` from the test project. `--mutate "<glob>"` limits files, `--since:<ref>` limits a run to a diff, and `--concurrency <n>` sets the workers. |
| JavaScript, TypeScript | StrykerJS | `npx stryker run` |
| Python | mutmut | `nix shell nixpkgs#mutmut -c mutmut run` |
| Rust | cargo-mutants | `nix shell nixpkgs#cargo-mutants -c cargo mutants` |
| Go | gremlins | `go run github.com/go-gremlins/gremlins/cmd/gremlins@latest unleash` |
| Java | PIT | the `pitest-maven` or Gradle plugin the build already supports |

A .NET build leaves MSBuild worker nodes and the compiler server running after it ends, and they hold memory for the whole run. Before a capped run, set `MSBUILDDISABLENODEREUSE=1` and `UseSharedCompilation=false`.
