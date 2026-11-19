# Dependencies level

Proves **Known vulnerabilities** ([STANDARDS.md](../../STANDARDS.md), Security).

- **A Nix build** (`flake.nix` or `default.nix`): `vulnix --json` reads the build's closure against published CVEs. A finding names the package and each CVE. vulnix exits 2 on findings.
- **Any other repo**: vulnix does not apply, so scorecard's Vulnerabilities check reads the forge's dependency data, on GitHub or GitLab.
- The fix takes the fixed version, or the pull request says why the CVE does not reach this build.
