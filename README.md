# SpatialBoard

An infinite 2D canvas workspace built with Flutter. Place cards anywhere, pan and zoom across a huge board, and keep your ideas in space instead of in a list.

**Live demo:** `TODO: add link` | **Demo video:** `TODO: add link`

![SpatialBoard screenshot]

---

## Table of contents

1. [What it does](#what-it-does)
2. [Controls](#controls)
3. [Tech stack](#tech-stack)
4. [How it works](#how-it-works)
5. [Load testing](#load-testing)
6. [Run it](#run-it)
7. [Project structure](#project-structure)
8. [Limitations](#limitations)
9. [Use of AI](#use-of-ai)

---

## What it does

- **Infinite canvas** with smooth pan and zoom. Zoom is centered on your fingers or cursor.
- **Cards** with a title and rich text (bold, italic, underline, bullet lists) and a background color.
- **Hold to pick up.** Press and hold a card, and it pops up with a scale animation. Then drag it anywhere.
- **Edge auto-scroll.** Drag a card to the edge of the screen and the canvas scrolls with it.
- **Read-only mode.** Existing cards open locked, with the toolbar and colors hidden, so reading is safe. A switch unlocks editing.
- **Delete with confirmation.** A small "Are you sure?" dialog protects against accidental deletes.
- **Not getting lost.** Older and newer buttons fly the camera through cards in creation order, and **Show all** zooms out to fit every card.
- **Load-test generator.** Start the app with thousands of generated cards to check performance.

---

## Controls

| Action | Touchscreen | Mouse / laptop touchpad |
|---|---|---|
| Pan the canvas | Drag one finger on empty space | Two-finger touchpad scroll, or mouse wheel |
| Zoom | Pinch | Touchpad pinch |
| Pick up a card | Press and hold (about 300 ms) | Press and hold |
| Move a card | Drag after it pops up | Drag after it pops up |
| Open a card | Quick tap | Quick click |
| Add a card | The **+** button | The **+** button |
| Older / newer card | The `<` and `>` buttons | The `<` and `>` buttons |
| Fit everything on screen | The **Show all** button | The **Show all** button |

On a laptop, one finger on the touchpad only moves the cursor, so only the two-finger gesture pans. This is intentional.

---

## Tech stack

| Area | What |
|---|---|
| Framework | Flutter (Dart), targeting the web |
| Rendering | `CustomPainter`, `RepaintBoundary` |
| State | `ValueNotifier`, `Listenable.merge` (no `setState` during pan or drag) |
| Input | `Listener` with raw pointer events |
| Animation | `AnimationController`, `Ticker` |
| Rich text | `flutter_quill` |
| Profiling | Chrome DevTools |

---

## How it works

### 1. Two coordinate spaces

| Space | Meaning | Examples |
|---|---|---|
| **World** | The endless sheet where cards live. Does not change when you pan or zoom | `item.position` |
| **Screen** | Pixels on the display | Pointer positions |

The **camera** is the screen position where the world's origin (0, 0) is drawn. One formula connects everything:

```
screen = world × zoom + camera
world  = (screen − camera) / zoom
```

Every conversion in the app is this formula rearranged. Distances convert with `÷ zoom` or `× zoom`.

### 2. Spatial grid and culling

Cards are stored in a hash grid keyed by cell `(row, column)`. Each frame:

1. The screen is converted to a rectangle in world units: `(−camera / zoom)` with size `screen / zoom`.
2. Only the cells that rectangle covers are read.
3. A precise rectangle overlap test drops cards that are only in an edge cell.

Cards that are far away are never looked at. The last result is cached and reused while the visible cell range and the scene version are unchanged.

### 3. Two-layer rendering

| Layer | Draws | Repaints when |
|---|---|---|
| **Static** | Every idle card | Camera changes, or the scene changes (add, delete, drop, edit) |
| **Dynamic** | The card being held | Every frame during a drag |

During a drag the camera is still, so only the dynamic layer repaints. Each layer sits in its own `RepaintBoundary`.

### 4. Repaint without rebuild

A single `Controller` object holds the data and a few small notifiers (camera, zoom, scene version, drag offset). Each painter subscribes to the notifiers it needs through `CustomPainter`'s `repaint` parameter. Panning and dragging never call `setState`, so the widget tree is not rebuilt. Only the paint step runs.

### 5. Input: a small state machine

One `Listener` receives all pointer events and drives a state machine:

| State | Meaning |
|---|---|
| Idle | Nothing happening |
| Pending | Finger is on a card, waiting to see if it is a hold or a tap |
| Armed | Held long enough. The card is picked up |
| Panning | The canvas is being moved |

- A hold timer promotes **Pending** to **Armed**.
- Moving more than a small threshold during **Pending** cancels the hold and turns the touch into a pan.
- A quick release while **Pending** counts as a tap and opens the card.
- A cancelled touch is handled exactly like a release, so nothing gets stuck.
- Only one pointer owns a gesture at a time.

### 6. Zoom around a point

Zooming must keep the world point under your fingers fixed. With `ratio = newZoom / zoom` (after clamping to the zoom limits):

```
newCamera = focal − (focal − camera) × ratio
```

Touchpad pinch events give a cumulative scale, so the code divides by the previous value to get the change per event.

### 7. Moving a card at any zoom

Pointer movement is in screen pixels, but card positions are in world units. The drag offset adds `delta / zoom`, so the card stays under the finger at every zoom level. Edge auto-scroll moves the camera and moves the drag offset the opposite way, so the card stays under the finger while the canvas slides.

### 8. Fly-to and Show all

The camera can animate to a card or to fit all cards. Solving the main formula for the camera:

```
camera = screenCenter − targetWorldPoint × zoom
```

**Show all** computes the bounding box of every card, picks `zoom = min((screenW − 2·pad) / boxW, (screenH − 2·pad) / boxH)` (capped at 1.0 and floored at the minimum zoom), and flies to its center. **Older / newer** step through a list of card ids kept in creation order.

### 9. The card editor

Rich text is stored as Delta JSON in a separate map keyed by card id. The card itself holds plain text. The canvas draws only a title and an ellipsized body, which is much cheaper than rendering rich text for every card. The editor opens when you tap a card.

Editor load time was reduced by:
- a 4-button toolbar instead of the full one, and no image or video embeds
- creating the theme once instead of on every build
- using notifiers so changing the color rebuilds only the swatches and the panel
- mounting the heavy editor widget one frame after the dialog appears
- delaying keyboard focus until the dialog animation ends

---

## Load testing

The app can generate fake boards at startup, so you do not need to edit code:

```bash
# 10,000 uniformly spread cards
flutter run -d chrome --profile --dart-define=SEED=10000

# 100,000 cards in dense clusters
flutter run -d chrome --profile --dart-define=SEED_LAYOUT=clustered --dart-define=SEED=100000

# Mixed card sizes
flutter run -d chrome --profile --dart-define=SEED=50000 --dart-define=SEED_MIXED=true
```

| Flag | Values | Default |
|---|---|---|
| `SEED` | Number of cards | `0` (empty board) |
| `SEED_LAYOUT` | `uniform`, `grid`, `clustered` | `uniform` |
| `SEED_MIXED` | `true` or `false` | `false` |

The generator uses a fixed random seed, so the same command always produces the same board. Always measure in **profile or release mode**, because debug mode is much slower.

---

## Run it

**Requirements:** Flutter SDK (`TODO: add the version you used`) and Chrome.

```bash
git clone https://github.com/TODO/spatial_world.git
cd spatial_world
flutter pub get
flutter run -d chrome
```

**Release build:**

```bash
flutter build web --release
```

**GitHub Pages:** build with the repository name as the base path, then publish `build/web`:

```bash
flutter build web --release --base-href "/spatial_world/"
```

**Web setup note:** in `web/index.html`, the following style stops the browser's horizontal swipe from triggering "back" navigation while you pan with a touchpad:

```html
<style>
  html, body { overscroll-behavior: none; }
</style>
```

`flutter_quill` needs its localization delegate in `MaterialApp` (already set up in this project).

---

## Project structure


```
lib/
  main.dart                       App entry and theme
  spatial_board.dart              Board page: input handlers, layers, navigation buttons
  widgets/
    split_layer.dart              Controller, data model, painters, grid, camera, seeding
    card_editor_dialog.dart       Editor dialog: title, colors, toolbar, read-only, delete
web/
  index.html
```

---

## Limitations

Being honest about what this project does not do yet:

- **No persistence.** Boards live in memory and are lost on reload.
- **No undo or redo.** Delete is permanent.
- **Single user, single device.** No sync or collaboration.
- **Text only on the canvas.** The editor does not support images or video.
- **A fixed grid cell size.** Very dense clusters put many cards in one cell, which is the grid's weak spot.
- **Extreme zoom-out can be slow.** The visible-cell loop iterates every cell in the window, including empty ones.
- **Hit testing scans the visible cards.** That is fast at normal zoom, but linear in the number of visible cards.

---

## Use of AI

I used an AI assistant (Claude, by Anthropic) for help with parts of this project, but not for everything. It helped me with:

- explaining concepts such as coordinate spaces, culling, and `CustomPainter` repaint behavior
- reviewing my code and helping to track down bugs
- suggesting and drafting some of the code, which I then read, tested, and changed
- drafting this README

I made the product decisions, integrated and ran the code, tested it, profiled it in the browser, and I am responsible for the final result.

`TODO: edit this section so it matches exactly what you did.`

---