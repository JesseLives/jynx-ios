# jynx-ios

iOS apps written in SwiftUI. They are built unsigned on GitHub Actions and installed with Sideloadly.

- `App/` Jynx
- `Sales/`

The logic lives in the Swift packages, which have tests:

```
cd Packages/JynxKit && swift test
```

A free Apple ID signs an app for 7 days, after that it has to be reinstalled.
