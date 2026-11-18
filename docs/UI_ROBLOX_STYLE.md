# Roblox's own UI style (reference for our top bar and panels)

What Roblox's current top bar and dark menus look like, with the numbers we
copy and where they come from. Our code: `src/client/UI/Theme.luau`,
`Icons.luau`, `Panel.luau`, `Button.luau`, `Controllers/MenuController.luau`.

## Top bar (2024+ "new topbar" / unibar)

| What | Value | Source |
|---|---|---|
| Pill height | **44 px** (min width 44: a lone icon is a circle) | TopbarPlus v3 `Themes/Default.lua`: `Widget MinimumHeight 44`, `MinimumWidth 44`; measured 44 px on the player's screenshot |
| Corner | full pill (`UICorner` scale 1) | TopbarPlus `IconCorners CornerRadius UDim.new(1, 0)` |
| Background | black at alpha 0.7 (**transparency 0.3**) | UIBlox `DarkTheme.lua`: `BackgroundUIContrast = Black, Transparency 0.3`; screenshot: Roblox pill reads RGB 22 over a 70 grey world (70 × 0.3 ≈ 21) |
| Icon | **22 px** (half the pill), white, line icons ~2 px | TopbarPlus `IconImageScale 0.5`; screenshot: menu / chat / mic icons are 21-22 px, outline style |
| Grouped pill | several icons in one pill, one ~42-44 px slot each (menu + chat + mic ≈ 128 px wide) | measured on the screenshot |
| Gap between pills | 8 px | TopbarPlus (`startInset` on the new bar), and our pills on the screenshot |
| Hover | white at alpha 0.1 behind the icon | UIBlox `BackgroundOnHover = White, Transparency 0.9` |
| Pressed | black at alpha 0.3 | UIBlox `BackgroundOnPress` |
| Selected / open | a pale round "spot" (RGB 208, 217, 251) behind the icon, inside the 4 px border (36 px) | TopbarPlus `IconSpot BackgroundColor3 (208,217,251), Transparency 0.85, "Selected"`; `Widget BorderSize 4` |
| Label | Builder Sans **Bold 16** | TopbarPlus `IconLabel FontFace BuilderSans Bold`, `TextSize 16` |
| Badge | white circle 20 px, dark number 13 px, top right | TopbarPlus `Notice Size 20×20`, `NoticeLabel TextSize 13`, `Notice.lua` white background; UIBlox `Badge = White`, `BadgeContent = Flint` |
| Dropdown / panel | RGB 18, 18, 21 at transparency **0.08** | TopbarPlus `Dropdown BackgroundColor3 (18,18,21)`, `BackgroundTransparency 0.08` |

## Dark theme palette (menus, settings)

From UIBlox (`App/Style/Colors.lua`, `Themes/DarkTheme.lua`), the library
Roblox's own app and in-experience menus are built with:

| Name | RGB | Hex | Use (Roblox) | Ours (`Theme.Colors`) |
|---|---|---|---|---|
| Obsidian | 17, 18, 20 | `#111214` | muted background | — |
| Carbon | 25, 27, 29 | `#191B1D` | contrast background, nav bar | — |
| Slate | 35, 37, 39 | `#232527` | default background | `Card` |
| Flint | 57, 59, 61 | `#393B3D` | UI fills, badge text | `CardHi` |
| Graphite | 101, 102, 104 | `#656668` | default UI lines | — |
| Pumice | 189, 190, 190 | `#BDBEBE` | default text | `Muted` |
| White | | `#FFFFFF` | emphasis text, icons | `InkHi` |
| Divider | white, transparency 0.8 | | thin lines | `DIVIDER_TRANSPARENCY` (0.85) |
| Surface 0 | 18, 18, 21 | `#121215` | roblox.com dark surface | `Surface` (panel plate) |

- Font: **Builder Sans** (Roblox's own; `rbxasset://fonts/families/BuilderSans.json`),
  weights 400 / 500 / 700. Headings 20-24 bold, body 14-16, labels 12.
- Corners: 8 px on inputs, buttons, cards (`--radius-medium`), full on pills.
  We use 12 px on the big panels.
- Buttons: primary "system" button = **white fill, dark (Flint) text**
  (UIBlox `SystemPrimaryDefault = White`, `SystemPrimaryContent = Flint`);
  secondary = white outline at alpha 0.3 (`SecondaryDefault`).
- No heavy strokes, no glows, no gradients: flat greys, white text.

## Sources

- TopbarPlus v3.5.0 (the open-source copy of Roblox's bar), theme defaults:
  https://github.com/1ForeverHD/TopbarPlus/blob/main/src/Features/Themes/Default.lua
  and `src/Elements/Container.lua`, `src/Elements/Notice.lua`
- TopbarPlus DevForum thread: https://devforum.roblox.com/t/topbarplus-v331-construct-topbar-icons-with-ease-customise-them-with-themes-dropdowns-captions-labels-and-more/1017485
- UIBlox dark theme and colours (Roblox client files, mirrored by Roblox-Client-Tracker):
  https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/LuaPackages/Packages/_Index/UIBlox/UIBlox/App/Style/Themes/DarkTheme.lua
  and `.../UIBlox/App/Style/Colors.lua`
- `GuiService.TopbarInset` (the free part of Roblox's bar; 58 px tall on the new bar):
  https://create.roblox.com/docs/reference/engine/classes/GuiService#TopbarInset
- roblox.com Foundation tokens (dark surface `#121215`, radius 8, Builder Sans), summarised at
  https://www.shadcn.io/design/roblox
- The player's screenshot of the bar (menu / chat / mic pill circled), measured in pixels.
