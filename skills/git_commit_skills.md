# Git Commit Message Skills

**AI Agent Skills for Professional Git Commit Messages**

This document provides guidelines for writing professional, standardized Git commit messages following Conventional Commits specification.

---

## Conventional Commits Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Rules:**

- **One-line commits:** `<type>: <subject>` (most common)
- **Subject:** Maximum 50-72 characters, lowercase, no period at end
- **Body:** Optional, detailed explanation (wrap at 72 characters)
- **Footer:** Optional, breaking changes, issue references

---

## Commit Types

### 1. **feat** - New Features

A new feature for the user or a significant addition.

**Examples:**

```bash
feat: add user authentication with Firebase
feat: implement conversation AI response system
feat: add voice recording functionality
feat: create scenario selection screen
```

---

### 2. **fix** - Bug Fixes

A bug fix that resolves an issue in the code.

**Examples:**

```bash
fix: resolve crash on conversation start
fix: correct API endpoint URL for production
fix: prevent memory leak in audio player
fix: handle null user data gracefully
```

---

### 3. **chore** - Maintenance Tasks

Routine tasks, tooling, dependencies, or configuration changes that don't modify src or test files.

**Examples:**

```bash
chore: setup monorepo structure with Flutter client architecture
chore: update dependencies to latest versions
chore: configure CI/CD pipeline
chore: add .gitignore for Flutter project
chore: setup Firebase configuration
```

---

### 4. **docs** - Documentation

Documentation changes only (README, comments, guides).

**Examples:**

```bash
docs: add API integration guide
docs: update README with setup instructions
docs: create architecture documentation
docs: add code comments for AI service
```

---

### 5. **style** - Code Style/Formatting

Code formatting, whitespace, semicolons, etc. (no functional changes).

**Examples:**

```bash
style: format code with dartfmt
style: apply consistent indentation
style: organize imports alphabetically
style: fix linting warnings
```

---

### 6. **refactor** - Code Refactoring

Code changes that neither fix bugs nor add features (restructuring).

**Examples:**

```bash
refactor: extract conversation logic to repository
refactor: simplify authentication flow
refactor: move constants to separate file
refactor: optimize widget rebuild performance
```

---

### 7. **test** - Testing

Adding or updating tests (unit, widget, integration).

**Examples:**

```bash
test: add unit tests for conversation controller
test: create widget tests for custom button
test: add integration tests for login flow
test: increase test coverage to 80%
```

---

### 8. **perf** - Performance Improvements

Code changes that improve performance.

**Examples:**

```bash
perf: optimize image loading with caching
perf: reduce app startup time by 30%
perf: implement lazy loading for conversation list
perf: optimize database queries
```

---

### 9. **build** - Build System

Changes to build system, dependencies, or external configurations.

**Examples:**

```bash
build: upgrade Flutter to 3.16.0
build: add hive dependency for local storage
build: configure Android release signing
build: setup webpack configuration
```

---

### 10. **ci** - Continuous Integration

CI configuration files and scripts (GitHub Actions, CircleCI, etc.).

**Examples:**

```bash
ci: add GitHub Actions workflow for Flutter
ci: setup automated testing on PR
ci: configure deployment to Firebase
ci: add code coverage reporting
```

---

### 11. **revert** - Revert Changes

Revert a previous commit.

**Examples:**

```bash
revert: revert "feat: add experimental AI feature"
revert: revert commit abc1234
```

---

## Commit Message Best Practices

### ✅ DO

1. **Use imperative mood** (like giving commands)
   - ✅ "add feature" not "added feature" or "adds feature"
   - ✅ "fix bug" not "fixed bug" or "fixes bug"

2. **Keep subject line short** (50-72 characters)
   - ✅ `feat: add user authentication`
   - ❌ `feat: add user authentication system with Firebase and email verification and password reset`

3. **Use lowercase** for type and subject
   - ✅ `fix: resolve navigation issue`
   - ❌ `Fix: Resolve Navigation Issue`

4. **Be specific and descriptive**
   - ✅ `fix: prevent crash when user data is null`
   - ❌ `fix: bug fix`

5. **Reference issues when applicable**
   - ✅ `fix: resolve login timeout (#123)`
   - ✅ `feat: add dark mode (closes #456)`

### ❌ DON'T

1. **Don't use periods at the end**
   - ✅ `feat: add login screen`
   - ❌ `feat: add login screen.`

2. **Don't use vague messages**
   - ❌ `fix: fixed stuff`
   - ❌ `chore: updates`
   - ❌ `feat: changes`

3. **Don't mix multiple changes**
   - ❌ `feat: add login and fix navigation and update dependencies`
   - ✅ Make separate commits for each change

4. **Don't use past tense**
   - ❌ `added new feature`
   - ✅ `add new feature`

---

## Commit Scope (Optional)

Scope provides additional context about what part of the codebase is affected.

**Format:** `<type>(<scope>): <subject>`

**Examples:**

```bash
feat(auth): add Google sign-in
fix(api): resolve timeout error
chore(deps): update Flutter dependencies
docs(readme): add installation instructions
test(controllers): add home controller tests
refactor(ui): simplify button components
```

**Common Scopes for Flutter Projects:**

- `auth` - Authentication
- `api` - API/Backend integration
- `ui` - User interface
- `db` - Database
- `deps` - Dependencies
- `config` - Configuration
- `controllers` - State management
- `models` - Data models
- `services` - Business services
- `widgets` - UI components

---

## Multi-line Commits (For Complex Changes)

For complex changes, use body and footer:

```bash
feat: implement AI conversation analysis

Add machine learning model to analyze user speech patterns
and provide real-time feedback on:
- Tone and sentiment
- Pace and clarity
- Word choice suggestions

Uses TensorFlow Lite for on-device processing.

Closes #234
Breaking change: requires minimum Android API 26
```

**Format:**

- **Subject line:** Brief summary
- **Blank line:** Separator
- **Body:** Detailed explanation (why, what, how)
- **Blank line:** Separator
- **Footer:** Issue references, breaking changes

---

## Breaking Changes

Use `BREAKING CHANGE:` in footer or `!` after type.

**Examples:**

```bash
feat!: migrate to Flutter 3.x

BREAKING CHANGE: minimum Dart SDK version is now 3.0.0

refactor!: change API response structure

BREAKING CHANGE: User model now uses `userId` instead of `id`
```

---

## Real-World Examples for CommuniQ Project

### Initial Setup

```bash
chore: setup monorepo structure with Flutter client architecture
chore: initialize Flutter project with base configuration
chore: add .gitignore and production-ready folder structure
```

### Feature Development

```bash
feat: create conversation scenario selection UI
feat: implement AI-powered speech analysis
feat: add real-time feedback during practice
feat: integrate Firebase for user authentication
feat: implement conversation recording functionality
```

### Bug Fixes

```bash
fix: resolve audio playback crash on iOS
fix: prevent duplicate conversation saves
fix: correct timestamp formatting in history
fix: handle network timeout gracefully
```

### Refactoring

```bash
refactor: extract conversation logic to repository layer
refactor: migrate state management to GetX
refactor: simplify navigation routing structure
refactor: optimize widget tree for better performance
```

### Testing

```bash
test: add unit tests for conversation controller
test: create integration tests for login flow
test: add widget tests for custom components
```

### Documentation

```bash
docs: add Flutter architecture guide for AI agents
docs: update README with setup instructions
docs: create API integration documentation
```

### Dependencies

```bash
build: add hive for local database storage
build: integrate firebase_core and firebase_auth
build: add get and get_it for state management
build: upgrade Flutter SDK to 3.16.0
```

---

## Quick Reference Table

| Type       | Use Case         | Example                               |
| ---------- | ---------------- | ------------------------------------- |
| `feat`     | New feature      | `feat: add user profile screen`       |
| `fix`      | Bug fix          | `fix: resolve login validation error` |
| `chore`    | Maintenance      | `chore: update dependencies`          |
| `docs`     | Documentation    | `docs: add API documentation`         |
| `style`    | Formatting       | `style: format code with dartfmt`     |
| `refactor` | Code restructure | `refactor: simplify auth logic`       |
| `test`     | Testing          | `test: add unit tests for models`     |
| `perf`     | Performance      | `perf: optimize image loading`        |
| `build`    | Build system     | `build: add new dependency`           |
| `ci`       | CI/CD            | `ci: add GitHub Actions workflow`     |

---

## Validation Checklist

Before committing, check:

- [ ] Used correct commit type
- [ ] Subject is imperative, lowercase, under 72 chars
- [ ] No period at end of subject
- [ ] Commit message is clear and specific
- [ ] Related files are staged
- [ ] No unnecessary files in commit
- [ ] One logical change per commit

---

## Git Workflow Best Practices

### Commit Frequently

- Commit after completing each logical unit of work
- Small, focused commits are better than large commits
- Makes it easier to review and revert if needed

### Commit Message Template

```bash
# <type>: <subject>
# |<----  Max 50 chars  ---->|

# Optional body
# |<----  Wrap at 72 chars  -------------------------------------------------->|

# Optional footer
# Issue references, breaking changes

# Types: feat, fix, chore, docs, style, refactor, test, perf, build, ci, revert
# Remember: Use imperative mood, lowercase, no period at end
```

### Example Commit Sequence for Feature

```bash
git add lib/views/login_view/
git commit -m "feat: create login screen UI"

git add lib/controllers/auth_controller/
git commit -m "feat: implement authentication logic"

git add lib/services/auth_service.dart
git commit -m "feat: add Firebase authentication service"

git add test/controllers/auth_controller_test.dart
git commit -m "test: add unit tests for auth controller"

git add README.md
git commit -m "docs: update README with auth setup"
```

---

## Tools & Automation

### Commitlint (Optional)

Enforce commit message conventions:

```json
// .commitlintrc.json
{
  "extends": ["@commitlint/config-conventional"]
}
```

### Git Hooks (Optional)

```bash
# .git/hooks/commit-msg
#!/bin/sh
npx --no -- commitlint --edit $1
```

---

## Resources

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Angular Commit Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit)
- [Semantic Versioning](https://semver.org/)

---

**Last Updated:** February 22, 2026
**For:** CommuniQ - AI Based Conversation Simulator
