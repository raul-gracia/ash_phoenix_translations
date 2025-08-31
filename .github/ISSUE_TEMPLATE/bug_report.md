---
name: Bug report
about: Create a report to help us improve
title: '[BUG] '
labels: 'bug'
assignees: ''
---

## Describe the bug
A clear and concise description of what the bug is.

## To Reproduce
Steps to reproduce the behavior:

1. Configure resource with '...'
2. Call function '....'
3. See error

## Expected behavior
A clear and concise description of what you expected to happen.

## Actual behavior
What actually happened, including any error messages.

## Code Example
```elixir
# Minimal code example that reproduces the issue
defmodule MyApp.Product do
  use Ash.Resource,
    extensions: [AshPhoenixTranslations]
  
  translations do
    # Your configuration
  end
end
```

## Environment
- Elixir version: [e.g., 1.17.3]
- OTP version: [e.g., 27.0]
- Ash version: [e.g., 3.0.0]
- AshPhoenixTranslations version: [e.g., 1.0.0]
- Phoenix version (if applicable): [e.g., 1.7.0]

## Additional context
Add any other context about the problem here.