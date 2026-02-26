[한국어](CONTRIBUTING.md) | English

# Contributing Guide

Thank you for contributing to prompt-vault! 🎉

## How to Contribute

### Bug Reports

1. Check existing issues on [GitHub Issues](https://github.com/lemon-etvibe/prompt-vault/issues)
2. If no duplicate exists, create a new issue
3. Please include:
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment info (OS, Claude Code version, jq version)

### Feature Requests

1. Create a Feature Request issue on [GitHub Issues](https://github.com/lemon-etvibe/prompt-vault/issues)
2. Describe the use case for your proposed feature
3. If possible, suggest an implementation approach

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "feat: add my feature"`
4. Push the branch: `git push origin feature/my-feature`
5. Create a Pull Request

## Code Style

### Shell Scripts
- Validate with `shellcheck`
- Comments in Korean (한글)
- Use `set -euo pipefail`
- Function names in snake_case

### Markdown
- Follow CommonMark standard
- User-facing docs: Korean default + English `.en.md` variant
- AI-facing docs (CLAUDE.md, SKILL.md): English

### HTML Templates
- Use Tailwind CSS CDN
- Pure static HTML, no build process
- Placeholders use `{{MARKER_NAME}}` format

## Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation changes
- `chore:` — Build/tool changes
- `refactor:` — Code refactoring

## License

All contributions are distributed under the MIT License.
