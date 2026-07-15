# Q3 Arena + Team Arena Key Forge

> A tiny offline Windows key-file utility by **SpiRaL'**, wrapped in a bloody late-90s Quake/Doom-inspired interface.

![Windows](https://img.shields.io/badge/platform-Windows-7a120c)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-cd5b18)
![License](https://img.shields.io/badge/license-GPL--2.0--only-9aa343)

The tool generates strings accepted by the open-source Quake III Arena validation routines and can write them to the folder layout used by Quake III and compatible community ports. It works entirely offline and does not patch or modify any executable.

## Features

- Quake III Arena key generation
- Quake III Team Arena key generation with checksum display
- One-click clipboard copy
- Native **Save As** dialog for choosing each key-file destination
- Scorched-metal, rust and blood WinForms interface
- No install, dependencies, network access or bundled game files

## Requirements

- Windows 7 or newer
- Windows PowerShell 5.1 or newer
- A legally obtained Quake III Arena installation or a compatible source port such as [ioquake3](https://ioquake3.org/)

## Quick start

1. Download or clone this repository.
2. Keep `KEYGEN.bat` beside the `keygen-script` folder.
3. Double-click `KEYGEN.bat`.
4. Select **FORGE** or **FORGE BOTH**. Generated values are copied automatically.
5. Select **WRITE** or **WRITE BOTH**. A standard Windows dialog asks where each `q3key` file should be saved.

The utility never creates game folders automatically. For a normal installation, choose `baseq3/q3key` for Arena and `missionpack/q3key` for Team Arena in the save dialogs.

The generated `q3key` files are ignored by Git and must never be committed.

## How validation works

Both games use this 16-character alphabet:

```text
2 3 7 A B C D G H J L P R S T W
```

### Quake III Arena

The Arena UI validation checks for exactly 16 characters from the allowed alphabet. The utility writes a lowercase 16-character value to `baseq3/q3key`.

### Quake III Team Arena

Team Arena uses the same 16 characters plus a displayed checksum. The checksum is the sum of the ASCII values of the raw key, truncated to one byte and formatted as two hexadecimal digits.

```text
Display: XXXX-XXXX-XXXX-XXXX-CC
File:    XXXXXXXXXXXXXXXX
```

Only the raw 16-character value is written to `missionpack/q3key`; separators and checksum are display-only.

## Run from PowerShell

Launch the interface:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\keygen-script\keygen.ps1
```

Run the built-in generator and checksum tests without opening the interface:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\keygen-script\keygen.ps1 -SelfTest
```

## Source references

The validation behavior was reimplemented from the source code published by id Software:

| Source file | Function | Purpose |
| --- | --- | --- |
| [`code/q3_ui/ui_cdkey.c`](https://github.com/id-Software/Quake-III-Arena/blob/master/code/q3_ui/ui_cdkey.c) | `UI_CDKeyMenu_PreValidateKey` | Arena length and alphabet validation |
| [`code/client/cl_main.c`](https://github.com/id-Software/Quake-III-Arena/blob/master/code/client/cl_main.c) | `CL_CDKeyValidate` | Engine validation and checksum |
| [`code/client/cl_ui.c`](https://github.com/id-Software/Quake-III-Arena/blob/master/code/client/cl_ui.c) | `CLUI_SetCDKey` | Arena and Team Arena key storage |

## Legal and responsible use

This repository contains no Quake III game data, binaries or copyrighted art. It does not bypass executable protection or provide access to online services. Use it only with software you are legally entitled to use and in accordance with applicable law and server rules.

Quake, Quake III Arena and Team Arena are trademarks of their respective owners. This fan utility is not affiliated with or endorsed by id Software or Bethesda Softworks.

The project source is licensed under the [GNU General Public License v2.0 only](LICENSE).

---

*SpiRaL' // 1999 never died.*
