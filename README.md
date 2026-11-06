# Sky Jumper 🚀

2D-Jump-Spiel für iPhone (SwiftUI + SpriteKit, iOS 16+).

## So bekommst du die .ipa (ohne Mac)

1. Auf github.com ein neues Repository anlegen (z. B. `skyjumper`). Es darf auch privat sein.
2. **Den Inhalt dieses Ordners** hochladen. Wichtig ist der versteckte Ordner `.github/workflows/build.yml`.
   - Am einfachsten am PC mit GitHub Desktop, oder auf der Webseite über „Add file → Upload files“.
   - Lädst du über die Webseite hoch und fehlt danach der Ordner `.github`, gehst du so vor: „Add file → Create new file“, als Name `.github/workflows/build.yml` eingeben und den Inhalt hineinkopieren.
3. Im Repo auf **Actions** gehen. Der Build startet automatisch und dauert etwa 3–5 Minuten.
4. Danach liegt die `SkyJumper.ipa` unter **Releases** (rechts auf der Repo-Seite). Öffne den Link am iPhone und lade sie herunter.
5. Die .ipa mit **KSign** öffnen, mit deinem Zertifikat signieren und installieren. Fertig.

## Steuerung

- ◀ ▶ zum Lenken, auch in der Luft
- ⬆ zum Springen: kurz tippen gibt einen kleinen Sprung, gedrückt halten einen hohen Sprung
- In der Luft ein zweites Mal tippen löst einen **Doppelsprung mit Salto** aus
- Im Menü lässt sich „Sprungtaste links“ umschalten
- Am Rand rauslaufen bringt dich auf der anderen Seite wieder rein

## Features

- Plattformen: normal, beweglich (blau), zerbrechlich (sandfarben), Sprungfeder (pink)
- Von unten springst du durch, von oben landest du drauf
- Power-ups: 🚀 Rakete, 🧲 Münzmagnet
- Der Himmel wechselt mit der Höhe: Tag → Sonnenuntergang → Dämmerung → Weltall mit Sternen
- Highscore wird gespeichert und als goldene „BEST“-Linie im Level angezeigt
- Shop mit 8 Charakteren und 6 Sprung-Effekten (Staub, Funken, Feuer, Sternenstaub, Blitz, Regenbogen)
- Münzen sammelst du im Spiel, dazu gibt es einen Höhenbonus: Score ÷ 25

## Sparsam

Es gibt keine Bilddateien, alle Grafiken werden einmal per Code gezeichnet und zwischengespeichert. Das Spiel ist auf 60 FPS begrenzt, auch auf 120-Hz-iPhones, und Objekte außerhalb des Bildschirms werden gelöscht.
