> [!WARNING]
> **Projet personnel « vibecodé ».** Tout le code de ce dépôt (ou, pour un fork, toutes les modifications) a été écrit par **Claude** (Anthropic, via Claude Code), à la demande spécifique de [@NOxygen59](https://github.com/NOxygen59), pour **son appareil précis** :
>
> **iPad Pro 12,9" 5ᵉ génération (puce M1) — 512 Go de stockage, 8 Go de RAM — iOS 16.6.1, jailbreak Dopamine (rootless) + TrollStore.**
>
> Rien n'est testé ni prévu pour un autre appareil. Pas de support, pas de feuille de route : c'est un dépôt d'archive personnel, publié pour pouvoir reprendre le travail plus tard (modifications, mises à jour).

**Licence :** MIT (voir [LICENSE](LICENSE)). Inspiré de [hrtowii/dual-wield](https://github.com/hrtowii/dual-wield). Ce dépôt n'a pas de licence, donc aucun de son code n'est repris : tout est réécrit.

**Builds :** voir les [Releases](https://github.com/NOxygen59/dual-wield-pad/releases) (`.deb` rootless). Non testé sur l'iPad.

---

# Dual Wield Pad

Rootless tweak (Dopamine, iOS 16) for an iPad on a Magic Keyboard: as you close the screen, the
whole display is warped in perspective so that, from your seat, the picture stays where it was at
the reference angle. An iPad take on [hrtowii/dual-wield](https://github.com/hrtowii/dual-wield)
(MacBooks), written from scratch: dual-wield has no license, so none of its code is reused.

| dual-wield (macOS) | Dual Wield Pad (iPadOS) |
| --- | --- |
| Lid-angle HID sensor | Hinge angle from gravity (accelerometer), keyboard lying flat |
| ScreenCaptureKit capture + Core Image warp in an overlay | `sublayerTransform` of SpringBoard's window layers (apps included) |
| Settings window | Settings › Dual Wield Pad (PreferenceLoader) |

- `DWGeometry.c`: the projection (eye ray onto the turned screen), the four-point homography and
  the hinge angle. Tested on the Mac: `make test`.
- `Tweak.x`: SpringBoard hook, accelerometer, armed/active states, the warp, blur and fade.
- `dualwieldpadprefs/`: the Settings page (French).

Build (Theos does not accept spaces in the project path):

```sh
make package FINALPACKAGE=1
```
