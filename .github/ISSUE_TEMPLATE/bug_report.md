---
name: Bug report
about: Something Monolith generates is wrong, or a command fails
title: ''
labels: bug
---

**What command did you run?**

```bash
monolith new app --name MyApp --features widget,cloudKit --no-interactive
```

**What did you expect?**

<!-- e.g. "project.yml should declare a widget target with type: app-extension" -->

**What happened instead?**

<!-- Paste the relevant generated file path + content, or the error message. -->

**Environment**

- macOS version:
- Xcode version (`xcodebuild -version`):
- Swift version (`swift --version`):
- Monolith version (`monolith version`):
- Output of `monolith doctor` (if the issue might involve missing tools):

**Reproduction**

If possible, attach the `--save-config` JSON that reproduces the issue, or the smallest `--features` set that triggers it.
