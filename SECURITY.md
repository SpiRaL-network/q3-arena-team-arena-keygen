# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes |
| Earlier development snapshots | No |

## Reporting a vulnerability

Do not post sensitive key material, private installation paths or personal server details in a public issue.

For ordinary defects that do not expose sensitive information, open a GitHub issue with:

- the application version;
- the Windows and PowerShell versions;
- the action that failed;
- the exact error text with personal paths redacted; and
- whether the parser and `-SelfTest` pass.

For a vulnerability that could expose clipboard contents, overwrite unintended files, execute unexpected code or transmit data, use GitHub's private vulnerability reporting feature if it is available for the repository. Otherwise contact the maintainer privately before public disclosure.

Never attach a `q3key` file or generated value to a report.

## Security model

The expected application behavior is:

- no network access;
- no administrator requirement;
- no executable or game-data modification;
- no automatic game-directory creation;
- file output only after an explicit user selection; and
- overwrite confirmation for existing files.

A change that violates one of these properties should be treated as security-relevant.
