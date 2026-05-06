---
name: Bug report
about: Report a bug in the actor or docs
title: "[BUG] "
labels: bug
---

## Summary

<!-- One-line summary of what's broken -->

## Steps to reproduce

1. Action called: `<action:operation>`
2. Input (redact secrets):
   ```json
   {
     "action": "...",
     "params": {...}
   }
   ```
3. Expected: ...
4. Got: ...

## Failure payload (if any)

<!-- Paste the full {success:false, errorCode, error, hint, ...} payload here -->

```json
{}
```

## Apify run ID

<!-- e.g. abcdef123 — visible in the Apify console -->

## Environment

- Caller: <!-- n8n / Make / curl / custom code -->
- Actor build: <!-- e.g. 0.3.8 / latest -->
- Date: <!-- when this happened -->

## Notes

<!-- Anything else that might help: rate of occurrence, recent changes, etc. -->
