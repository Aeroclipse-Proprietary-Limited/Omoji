# Contributing to Omoji

Thank you for your interest in contributing to **Omoji** — a project built and maintained by [Aeroclipse Proprietary Limited](https://aeroclipse-bw.web.app). We welcome contributions from developers, designers, writers, and testers of all skill levels.

Please take a moment to review this guide before submitting a contribution. It helps us maintain a high standard of quality and makes the review process smoother for everyone.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Ways to Contribute](#ways-to-contribute)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)
- [Contact](#contact)

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](Code%20of%20Conduct.md). We are committed to fostering a welcoming, respectful, and inclusive community.

---

## Ways to Contribute

There are many ways to contribute beyond writing code:

- 🐛 **Report bugs** — Help us identify issues before users encounter them.
- 💡 **Suggest features** — Share ideas that could improve Omoji.
- 📖 **Improve documentation** — Fix typos, clarify instructions, or expand guides.
- 🧪 **Write tests** — Increase test coverage and improve reliability.
- 🔧 **Fix bugs or implement features** — Pick up an open issue and submit a pull request.
- 🌍 **Translate** — Help bring Omoji to more languages and communities.

---

## Getting Started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (latest stable)
- Git

### Fork & Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/<your-username>/Omoji.git
cd Omoji
flutter pub get
```

### Run the App

```bash
flutter run -d linux    # or -d macos
```

### Run Checks

Always run both of these before opening a pull request:

```bash
flutter analyze
flutter test
```

---

## Development Workflow

1. **Create a branch** from `main` for your work:
   ```bash
   git checkout -b fix/clipboard-crash
   # or
   git checkout -b feat/new-emoji-category
   ```
2. **Make your changes** — keep them focused and minimal in scope.
3. **Test thoroughly** — run `flutter test` and manually verify your change.
4. **Commit** with a clear, descriptive message (see [Commit Guidelines](#commit-guidelines)).
5. **Push** your branch and open a pull request against `main`.

---

## Commit Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/) for a clean, readable history.

**Format:**
```
<type>(<scope>): <short description>
```

**Types:**

| Type     | When to use                                    |
|----------|------------------------------------------------|
| `feat`   | A new feature                                  |
| `fix`    | A bug fix                                      |
| `docs`   | Documentation changes only                    |
| `style`  | Formatting, whitespace — no logic change      |
| `refactor` | Code restructuring — no feature or fix     |
| `test`   | Adding or updating tests                      |
| `chore`  | Build process, tooling, or dependency updates |

**Examples:**
```
feat(clipboard): add pinning support for clipboard entries
fix(emoji): correct rendering on HiDPI displays
docs(readme): update macOS installation steps
```

---

## Pull Request Guidelines

- **One concern per PR** — keep your changes focused on a single problem or feature.
- **Describe the change** — explain what the PR does, the problem it solves, and how it was tested.
- **Link related issues** — reference any relevant GitHub issues (e.g. `Closes #42`).
- **Be responsive** — if a reviewer requests changes, please address them in a timely manner.
- **No force-pushes** after review has begun, unless explicitly asked.

> **Note:** The Supplier of Systems (Aeroclipse Proprietary Limited) retains the right to accept, modify, or reject any contribution in accordance with the project's direction and architecture.

---

## Reporting Bugs

Please [open a GitHub issue](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/issues/new) and include:

- Your **operating system** and version
- Your **Omoji version** (visible in app Settings)
- **Steps to reproduce** the issue
- **Expected vs. actual behaviour**
- Any **error output** or logs

For **security vulnerabilities**, please do **not** open a public issue. See [SECURITY.md](SECURITY.md) for our responsible disclosure process.

---

## Requesting Features

[Open a GitHub issue](https://github.com/Aeroclipse-Proprietary-Limited/Omoji/issues/new) and describe:

- The **problem** you're trying to solve
- The **feature** you'd like to see
- Any **alternatives** you've considered

Feature requests are reviewed and prioritised by the Aeroclipse team. We appreciate your patience — this is a human-driven project.

---

## Contact

For general questions or feedback not suited to a GitHub issue:

**📧 Email:** [godlyttn@outlook.com](mailto:godlyttn@outlook.com)

---

_Thank you for contributing to Omoji. Every improvement, big or small, makes a difference. 💜_

**— Aeroclipse Proprietary Limited**
