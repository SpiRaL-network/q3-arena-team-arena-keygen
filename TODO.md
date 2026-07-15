# v1.0.0 release checklist

## Product wording

- [x] Use **Q3 Arena + Team Arena Keygen** consistently as the product name.
- [x] Describe the project consistently as an offline keygen.
- [x] State that the runtime requirement is Windows/PowerShell; lawful game ownership is the usage requirement.
- [x] Mention ioquake3 only as a newer open-source community engine, not as a keygen dependency.
- [x] State that generated keys are intended only for permitted community-server connections.
- [x] Add a professional in-app About dialog with legal, requirement and upstream information.
- [x] Redraw the interface with independent circuit-board, black, red and orange code-native visuals.

## Installation detection

- [x] Verify Steam AppID `2200` for Arena and `2350` for Team Arena.
- [x] Detect all Steam libraries from `libraryfolders.vdf` and read `appmanifest_2200.acf` / `appmanifest_2350.acf`.
- [x] Detect GOG Galaxy and offline-installer locations from GOG and Windows uninstall registry entries.
- [x] Detect original CD-ROM installations from id Software and Windows uninstall registry entries.
- [x] Detect ioquake3 user data at `%APPDATA%\Quake3` and common portable locations.
- [x] Include documented fallback paths without assuming they exist.
- [x] Deduplicate installations by normalized root path.

## Keygen workflow

- [x] Add a detected-installation selector to the interface.
- [x] Add a rescan button.
- [x] Add individual **INSTALL** actions and **INSTALL BOTH** for the selected detected installation.
- [x] Validate that `baseq3` / `missionpack` already exist; never create game folders.
- [x] Confirm before replacing existing generated data.
- [x] Keep manual **SAVE AS...** buttons so each generated key can be saved anywhere.
- [x] Add **SAVE BOTH AS...** and collect both distinct destinations before either write.
- [x] Show the detected source, path and available Arena/Team Arena targets.

## Quality and release

- [x] Extend `-SelfTest` to cover installation detection and direct installation helpers.
- [x] Test the BAT launcher and ensure zero WinForms errors.
- [x] Update README, LEGAL, SECURITY, CHANGELOG and the personal-project maintenance policy.
- [x] Update GitHub About/topics to use `keygen` terminology.
- [x] Replace the previous GitHub release/tag and verify the new first release `v1.0.0`.
