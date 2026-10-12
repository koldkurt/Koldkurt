# Koldkurt: project context for Claude

## The game
A Roblox arena shooter that combines:
- **Rivals (Roblox):** duel format (1v1 to 4v4, first to 5 rounds, small arenas), loadouts
  (primary / secondary / melee / utility), weapon unlocks, skins, wraps, cases,
  finishers, weapon mastery, ranked, challenges. Copy the *systems*, not Rivals' names, art or UI.
- **Max Payne:** the shootdodge (dive while shooting) and prone shooting.
  **No bullet time.** The dive is a dodge you can shoot from, balanced by a cooldown and
  a vulnerable landing.

## Decisions already made
- **Third-person**, over the shoulder. First-person may come later as an option, so don't
  build anything that rules it out.
- **R15 avatars only** (arm aiming uses IKControl).
- Code lives in this repo as a **Rojo** project (`default.project.json`, Rojo 7.4.4 via `rokit.toml`).
  Maps, models and UI layouts are built in Studio.
- All feel and tuning numbers go in `src/shared/MovementConfig.luau` (or similar config modules),
  not hardcoded in logic.
- Weapons will be data-driven (one config table per weapon).
- Hits must be validated on the server; never trust the client for damage.

## Layout (Rojo → Studio)
| Path | Studio location |
|---|---|
| `src/shared/` | ReplicatedStorage.Shared |
| `src/server/` | ServerScriptService.Server |
| `src/client/` (`init.client.luau` = LocalScript `Client`, siblings = its child ModuleScripts) | StarterPlayer.StarterPlayerScripts.Client |

When working directly in Studio (for example through a Studio MCP connection), keep Studio and these
files in sync. The files in this repo are the source of truth for code, so write code changes here too.

## What's built (see README.md for details)
- `CameraController`: over-the-shoulder camera, shoulder swap (V), wall collision, FOV kick, shake;
  makes the character face the camera while upright; `GetAimPoint()` gives the crosshair hit point.
- `DiveController`: shootdodge state machine Idle → Diving → Prone → Recovering. The dive key is Q.
  Uses PlatformStand + a velocity impulse + VectorForce (float) + AlignOrientation (horizontal pose).
- `AimPose`: IKControl on both arms pointing at the aim point.
- `AimReplicator` (client) + `AimRelay` (server): relay the arm-aim pose to other players,
  validated and rate-limited.

Status: written and syntax-checked but **not yet playtested in Studio**. The first job is to
get it running in Studio, playtest it and fix whatever turns up.

## Roadmap
1. ~~Shootdodge movement prototype~~ (needs playtest)
2. Test gun usable mid-dive + weapon framework + server-validated hit registration
3. Duel round loop (1v1, first to 5) and a first arena
4. Loadouts
5. Saving and economy (ProfileStore), weapon unlocks
6. Lobby UI, skins, cases, finishers
7. Team modes, ranked, challenges

## Conventions
- Luau, tabs, `.luau` extension, one module per system with a `Start()` function.
- Development branch: `claude/roblox-rivals-maxpayne-game-ps7ve9`.
