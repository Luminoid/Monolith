---
name: Feature request
about: Propose a new generator, feature flag, or retrofit path
title: ''
labels: enhancement
---

**Which kind of feature?**

- [ ] A new `AppFeature` / `PackageFeature` / `CLIFeature` flag
- [ ] A new retrofit path (`monolith add <feature>` for an existing project)
- [ ] A new shared generator (Makefile target, hook, CI config)
- [ ] An improvement to an existing generator
- [ ] Something else

**What problem does this solve?**

<!-- The repeatable thing you find yourself wiring by hand. -->

**Proposed `monolith` invocation**

<!-- e.g. `monolith new app --name X --features healthKit` -->

**Output you'd expect Monolith to generate**

<!-- Files added, snippets written into Info.plist / AppDelegate / project.yml, etc.
     Generator design is easier to discuss against concrete output. -->

**Interaction with existing features**

<!-- Does the new feature compose cleanly with widget / cloudKit / lumiKit?
     Does it auto-derive any other feature? Should it appear in the
     "Combinations with distinct output" table? -->
