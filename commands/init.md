---
description: "Initialize prompt-vault logging environment. Use when starting a new project, when .local/logs/ doesn't exist, or when the user says 'init', '초기화', 'set up logging'. Pass 'en' or 'ko' to set language directly."
argument-hint: [en|ko]
---

Run the `/prompt-vault:init` skill to set up the logging environment.

Pass language as argument to skip the language selection prompt:
- `/prompt-vault:init en` — initialize with English
- `/prompt-vault:init ko` — initialize with Korean (한국어)
- `/prompt-vault:init` — interactive language selection
