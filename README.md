# Koldkurt

A Roblox arena shooter: Rivals-style duels and progression with Max Payne-style
shootdodge movement (no bullet time). Third-person.

## Current state: shootdodge prototype

| Feature | Status |
|---|---|
| Over-the-shoulder camera (shoulder swap, wall collision, FOV kick, landing shake) | ✅ |
| Shootdodge: launch in move direction, floaty arc, body lies horizontal | ✅ |
| Chest turns toward crosshair mid-dive, arms aim at crosshair (IK) | ✅ |
| Land prone, roll onto back, spin to aim, get up | ✅ |
| Dive cooldown | ✅ |
| Other players see your dive pose and arm aim | ✅ |
| Shooting / weapons | ⏳ next |

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Look | Mouse | Right stick |
| **Dive** (in the direction you're moving; forward if standing still) | **Q** | X |
| Get up after landing | Space or Q (auto after 3s) | A or X |
| Swap shoulder | V | R3 |

## Setup in Roblox Studio

**The game needs R15 avatars:** Home → Game Settings → Avatar → Avatar Type **R15**.

### Option A: Rojo (recommended, keeps Studio in sync with this repo)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder.
2. Install the Rojo Studio plugin (`rojo plugin install`).
3. Run `rojo serve`, then in Studio open the Rojo plugin and click **Connect**.

### Option B: Copy and paste by hand

Create these in the Explorer and paste in each file's contents:

| Studio location | Type | Name | File |
|---|---|---|---|
| ReplicatedStorage | Folder | `Shared` | |
| ReplicatedStorage › Shared | ModuleScript | `MovementConfig` | `src/shared/MovementConfig.luau` |
| ServerScriptService | Script | `AimRelay` | `src/server/AimRelay.server.luau` |
| StarterPlayer › StarterPlayerScripts | LocalScript | `Client` | `src/client/init.client.luau` |
| …› Client (inside the LocalScript) | ModuleScript | `CameraController` | `src/client/CameraController.luau` |
| …› Client | ModuleScript | `DiveController` | `src/client/DiveController.luau` |
| …› Client | ModuleScript | `AimPose` | `src/client/AimPose.luau` |
| …› Client | ModuleScript | `AimReplicator` | `src/client/AimReplicator.luau` |
| …› Client | ModuleScript | `Crosshair` | `src/client/Crosshair.luau` |

Also set **StarterPlayer › EnableMouseLockOption** to off (the camera handles mouse lock itself).

Put a few parts in the baseplate for cover, press **Play**, and dive with **Q**.
To see replication, use Test → Clients and Servers → 2 players.

## Tuning

Every feel number (dive speed, float, cooldown, camera offset, and so on) is in
`src/shared/MovementConfig.luau`, with a comment on each one.

## How the dive works

```
Idle --Q--> Diving --touch ground--> Prone --Space/Q/timer--> Recovering --> Idle
```

- **Diving:** the humanoid is `PlatformStand`-ed and launched with a velocity
  impulse. A `VectorForce` cancels part of gravity for the float. An
  `AlignOrientation` lays the body flat, head first in the dive direction and chest
  turned toward the crosshair. `IKControl`s point both arms at the aim point.
- **Prone:** the body rolls onto its back and spins (at a limited turn speed) so
  the feet point at where you're aiming.
- **Replication:** the client owns its character's physics, so the body pose
  replicates for free. Arm IK is local-only, so `AimReplicator` sends the aim
  point (about 20Hz, unreliable) through the server's `AimRelay`, which validates
  and fans it out.

## Roadmap

1. ~~Shootdodge movement prototype~~
2. Weapon framework (data-driven configs) and server-validated hit registration
3. Duel round loop (1v1, first to 5), first arena
4. Loadouts (primary / secondary / melee / utility)
5. Saving and economy (ProfileStore), weapon unlocks
6. Lobby UI, skins, cases, finishers
7. Team modes, ranked, challenges
