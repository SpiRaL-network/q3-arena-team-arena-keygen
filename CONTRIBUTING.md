# Contributing

Thank you for helping improve Q3 Arena + Team Arena Key Forge.

## Scope

Contributions should preserve the project's narrow purpose: an offline, personal interoperability PoC for lawfully owned Quake III installations and permitted community-server use.

Changes must not:

- add game binaries, `pak` files, commercial assets or generated `q3key` files;
- add telemetry, remote key services or silent network access;
- create game directories without explicit user intent;
- weaken the Save As or overwrite confirmations;
- claim that a generated value is a game licence or proof of ownership; or
- facilitate ban evasion, unauthorized server access or distribution of copyrighted data.

## Development requirements

- Windows PowerShell 5.1 or later
- Windows Forms and System.Drawing
- Git

## Before submitting a change

1. Run the parser and self-test:

   ```powershell
   $errors = $null
   [System.Management.Automation.Language.Parser]::ParseFile(
       (Resolve-Path '.\keygen-script\keygen.ps1'),
       [ref]$null,
       [ref]$errors
   ) | Out-Null
   if ($errors) { $errors; exit 1 }

   powershell -NoProfile -ExecutionPolicy Bypass -File .\keygen-script\keygen.ps1 -SelfTest
   ```

2. Launch `KEYGEN.bat` and verify the interface opens without PowerShell errors.
3. Test Arena **WRITE**, Team Arena **WRITE**, and **WRITE BOTH** with disposable folders.
4. Confirm no generated `q3key` file appears in `git status`.
5. Update `CHANGELOG.md` for user-visible changes.
6. Keep documentation and the displayed application version consistent.

## Commit and pull-request guidance

- Keep commits focused and use an imperative or Conventional Commits-style subject.
- Explain the user-visible behavior and test evidence.
- Never include a real or generated key value in screenshots, logs or issue text.
- Link any upstream validation claim to a stable id Software source permalink.

By contributing, you agree that your contribution is distributed under GPL-2.0-only.
