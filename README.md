# Q3 Arena + Team Arena Keygen

[![Release](https://img.shields.io/github/v/release/SpiRaL-network/q3-arena-team-arena-keygen?display_name=tag&sort=semver)](https://github.com/SpiRaL-network/q3-arena-team-arena-keygen/releases)
![Windows](https://img.shields.io/badge/platform-Windows-7a120c)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-cd5b18)
[![License](https://img.shields.io/badge/license-GPL--2.0--only-9aa343)](LICENSE)

An offline, open-source keygen based on the local validation rules published in the **Quake III Arena** GPL source release, presented through a Quake III-inspired late-1990s Windows interface without reusing official logos or game assets.

> [!IMPORTANT]
> This keygen is intended only for owners of a lawfully acquired physical or digital copy of the relevant game. It does not grant a game licence, prove ownership, include game data, or authorize access to any server. Generated keys are intended only for personal use with community-operated servers whose rules permit them.

## Project scope

The project demonstrates a narrow technical fact visible in the GPL source release: local validation accepts a 16-character value from a fixed alphabet, while Team Arena can additionally display a two-digit checksum. The keygen creates such values, copies them to the clipboard, and either installs them into a detected lawful installation or lets the user save the generated data anywhere.

| This project is | This project is not |
| --- | --- |
| An offline keygen and interoperability PoC | A game, crack, patch, trainer or activation service |
| A reimplementation of published validation rules | A source of Quake III game assets or binaries |
| A personal compatibility and recovery tool | Proof that the user owns a Quake III licence |
| A WinForms interface with detected-install and Save As choices | A tool for evading bans, access controls or server rules |

The application makes no network requests, changes no executable, injects no code and never creates game directories.

## Requirements and permitted use

The keygen itself needs only a supported Windows/PowerShell environment. No game archive, `pak` file or game executable is needed to launch it or generate values.

Its intended use nevertheless requires that you:

1. Own a legitimate copy of **Quake III Arena**, obtained on physical media or from an authorized digital distributor.
2. Separately own **Quake III: Team Arena** if your edition does not include the mission pack.
3. Use generated keys only with your own lawful installation and for personal play.
4. Connect only to community-operated servers that permit locally generated keys.
5. Follow the rules, terms and access policies of every server you join.

Do not publish generated values, share them as substitutes for purchased licences, sell them, use them to misrepresent ownership, evade a suspension, or access a service without permission.

The maintained [ioquake3](https://ioquake3.org/) community engine is a modern open-source way to run Quake III content. It is mentioned as a related project and detected for convenience; it is not a dependency of this keygen.

## Supported environment

- Windows 7 or later
- Windows PowerShell 5.1 or later
- Windows Forms and System.Drawing (included with the supported Windows/.NET environment)

No installer, administrator access, game data, external dependency or internet connection is required to run the keygen. A lawfully acquired game installation is the usage requirement, not a runtime dependency.

## Quick start

1. Download a versioned source archive from [Releases](https://github.com/SpiRaL-network/q3-arena-team-arena-keygen/releases).
2. Keep `KEYGEN.bat` beside the `keygen-script` folder.
3. Double-click `KEYGEN.bat`.
4. Select **GENERATE** or **GENERATE BOTH**. Generated values are also copied to the clipboard.
5. To install directly, choose a detected installation, then use the Arena or Team Arena **INSTALL** button, or **INSTALL BOTH**. Review the exact target paths and confirm.
6. To keep generated data elsewhere, use an individual **SAVE AS...** button or **SAVE BOTH AS...**. The double action asks for both destinations before writing either value.
7. Select **ABOUT** for the in-app purpose, legal scope, requirements and upstream references.

Typical destinations are:

```text
Quake III Arena:       baseq3/q3key
Quake III Team Arena: missionpack/q3key
```

Direct installation writes only to existing `baseq3` and/or `missionpack` directories. The keygen never creates those directories. Manual **SAVE AS...** remains available even when no installation is detected.

### Common Windows locations

Detection combines registry data, Steam manifests and documented conventional paths. These defaults are not guarantees: Steam libraries, GOG installs and portable ioquake3 builds can be placed on any drive.

| Installation | Typical game root | Arena key | Team Arena key |
| --- | --- | --- | --- |
| Original CD-ROM on 64-bit Windows | `C:\Program Files (x86)\Quake III Arena` | `baseq3\q3key` | `missionpack\q3key` |
| Original CD-ROM on 32-bit Windows | `C:\Program Files\Quake III Arena` | `baseq3\q3key` | `missionpack\q3key` |
| Steam default library | `C:\Program Files (x86)\Steam\steamapps\common\Quake 3 Arena` | `baseq3\q3key` | `missionpack\q3key` |
| GOG Galaxy / offline installer | Commonly `C:\GOG Games\Quake III Arena`, or the folder shown by **Manage installation > Show folder** | `baseq3\q3key` | `missionpack\q3key` |
| ioquake3 per-user data | `%APPDATA%\Quake3` | `baseq3\q3key` | `missionpack\q3key` |
| Portable ioquake3 | Your chosen ioquake3 folder | `baseq3\q3key` | `missionpack\q3key` |

### What is detected

- **Steam:** every library declared in `libraryfolders.vdf`, using Arena AppID `2200` and Team Arena AppID `2350` manifests.
- **GOG:** GOG game registry entries, Windows uninstall entries and common Galaxy/offline-installer roots. GOG permits a custom installation directory, so the registry result takes priority.
- **Original CD-ROM:** id Software and Windows uninstall registry entries, plus the conventional `Program Files` locations shown above.
- **ioquake3:** `%APPDATA%\Quake3` user data and common portable/program locations. ioquake3 can be unpacked elsewhere, so manual **SAVE AS...** is always the fallback.

Each list entry shows its detected source, full path and whether Arena, Team Arena, or both target directories exist. It controls the two individual **INSTALL** buttons and **INSTALL BOTH**; unavailable targets are disabled. A confirmation names every destination and warns before replacement.

Manual saving is independent of the detected selector. Each **SAVE AS...** can target any file location. **SAVE BOTH AS...** collects two distinct destinations first and writes nothing if either dialog is cancelled, preventing an accidental partial save.

## Proof of concept: validation format

This section documents behavior in the official id Software source release at commit [`dbe4ddb`](https://github.com/id-Software/Quake-III-Arena/tree/dbe4ddb10315479fc00086f08e25d968b4b43c49). It describes local file-format validation only. It does not describe or promise acceptance by any external authentication service.

### 1. Shared alphabet and length

Both variants use exactly 16 characters selected from this alphabet:

```text
2 3 7 A B C D G H J L P R S T W
```

The Arena menu function [`UI_CDKeyMenu_PreValidateKey`](https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/q3_ui/ui_cdkey.c#L91-L123) checks that the input length is 16 and that every lowercase character belongs to the corresponding alphabet.

The engine function [`CL_CDKeyValidate`](https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/client/cl_main.c#L3265-L3322) also requires `CDKEY_LEN` characters. It normalizes lowercase ASCII letters to uppercase before applying the same alphabet test.

Arena values are displayed and written in lowercase by this utility. Team Arena values are displayed in uppercase. The engine validation is case-insensitive for those letters.

### 2. Team Arena checksum

For Team Arena, the display includes a two-digit hexadecimal checksum:

```text
XXXX-XXXX-XXXX-XXXX-CC
```

The calculation reproduced by the PoC is:

```text
normalized = uppercase(raw_16_character_key)
sum        = sum(ASCII value of each normalized character) modulo 256
checksum   = sum formatted as two hexadecimal digits
```

Equivalent pseudocode:

```text
sum = 0
for character in uppercase(key):
    reject character unless it belongs to 237ABCDGHJLPRSTW
    sum = (sum + ASCII(character)) & 0xFF

checksum = hex(sum, width=2)
```

The original C code stores the accumulator in a `byte`, formats it with `%02x`, and compares the checksum case-insensitively. This project displays uppercase hexadecimal for readability; the numerical value is identical.

### 3. File representation

Separators and the Team Arena checksum are presentation-only. The key file contains exactly the raw 16 ASCII characters:

```text
Displayed Team Arena value: TSBH-7CCG-DPWP-B2LT-84
Saved q3key content:        TSBH7CCGDPWPB2LT
Saved byte count:           16
```

The engine's [`Com_ReadCDKey`](https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/qcommon/common.c#L2253-L2276) reads 16 bytes from `q3key`; [`Com_AppendCDKey`](https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/qcommon/common.c#L2283-L2306) does the same for the unique mission-pack key. [`CLUI_SetCDKey`](https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/client/cl_ui.c#L707-L720) shows how the base key and optional second 16-byte key occupy separate positions in the client buffer.

### 4. Application flow

```text
User selects GENERATE
        |
        v
16 characters sampled from the published alphabet
        |
        +-- Arena: lowercase display
        |
        `-- Team Arena: uppercase display + checksum
        |
        v
Value copied to the clipboard
        |
        v
User selects a detected installation or chooses Save As
        |
        v
Exactly 16 ASCII characters written; no network, folder creation or binary modification
```

### 5. Built-in verification

The `-SelfTest` mode generates 100 Arena/Team Arena pairs and verifies:

- exact length and alphabet;
- Team Arena display structure;
- checksum recalculation;
- conversion from display format to the raw 16-character value;
- direct installation into existing temporary `baseq3` and `missionpack` targets; and
- structural validation of every detected installation result.

Run it with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\keygen-script\keygen.ps1 -SelfTest
```

## Privacy and security properties

- Fully offline at runtime; there is no telemetry, update check or remote API.
- Generated values are not logged or stored by the application.
- Clipboard use occurs only after an explicit generate action.
- Writes occur only after an explicit Save As choice or a confirmed detected installation.
- Existing data triggers a native Windows overwrite or replacement confirmation.
- Generated `baseq3/q3key` and `missionpack/q3key` paths are excluded by `.gitignore`.
- The script does not request elevation and should not be run as administrator.

Generated values should still be treated as private local configuration. Do not include generated `q3key` data in bug reports, screenshots, archives or commits.

## Legal notice and responsible-use policy

The following is project policy and general information, not legal advice.

### Engine source versus commercial game data

id Software published the **Quake III Arena engine source code** under the GNU General Public License. That source release does not make Quake III Arena, Team Arena, their `pak0.pk3` files, maps, textures, sounds, trademarks or other commercial assets freely distributable.

ioquake3 makes the same distinction in its official documentation: the engine is free software, while playing Quake III Arena still requires a purchased copy and the user's own game data.

### Intended use

This keygen is intended for personal interoperability, archival recovery and preservation-oriented use by legitimate owners on local installations and community-run servers that explicitly allow locally generated keys. It is not intended to replace a purchase, create additional licensed seats, defeat commercial authentication, impersonate another owner, evade moderation, or gain unauthorized access.

The GPL licence governs copying, modification and distribution of this project's source code. This responsible-use statement does not modify the GPL. It describes the purpose of the utility and does not grant any right to third-party game content or services.

### No affiliation or warranty

This is an independent fan-made project. It is not affiliated with, sponsored by, approved by or endorsed by id Software, Bethesda Softworks, ZeniMax Media, ioquake3, Valve, GOG or any server operator.

**Quake**, **Quake III Arena**, **Quake III: Team Arena** and related names and marks belong to their respective owners. All third-party rights are acknowledged. See [LEGAL.md](LEGAL.md) for the full project notice.

## Upstream and community references

- [id Software: Quake III Arena GPL Source Release](https://github.com/id-Software/Quake-III-Arena)
- [ioquake3 official website](https://ioquake3.org/)
- [ioquake3 source repository](https://github.com/ioquake/ioq3)
- [ioquake3 Player's Guide](https://ioquake3.org/help/players-guide/)
- [ioquake3 purchase information](https://ioquake3.org/buy/)

This repository does not vendor, fork or modify either upstream engine. Those projects are references for interoperability and lawful modern play.

## Development

Launch the interface directly:

```powershell
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\keygen-script\keygen.ps1
```

Inspect detection without opening WinForms:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\keygen-script\keygen.ps1 -DetectOnly
```

Repository layout:

```text
.
|-- KEYGEN.bat
|-- keygen-script/
|   `-- keygen.ps1
|-- CHANGELOG.md
|-- LEGAL.md
|-- LICENSE
`-- README.md
```

## Maintenance policy

This is a personal, maintainer-led project. External code or documentation contributions are not currently accepted. Public visibility and the GPL-2.0-only licence allow lawful inspection, redistribution and forks under the licence, but do not oblige the maintainer to review or merge pull requests, provide support, or implement requested features.

GitHub Issues are reserved for reproducible defects and responsible security reports. The tracked [TODO.md](TODO.md) documents the maintainer's own release checklist.

## Versioning and releases

Releases follow [Semantic Versioning](https://semver.org/). User-visible changes are recorded in [CHANGELOG.md](CHANGELOG.md). Version `1.0.0` is the first stable public release.

## Licence

Copyright (C) 2026 SpiRaL'.

This project's original source code is distributed under the [GNU General Public License v2.0 only](LICENSE). The licence applies to this repository's code and documentation, not to any third-party Quake III game data, product name or trademark.

---

*SpiRaL' // 1999 never died.*
