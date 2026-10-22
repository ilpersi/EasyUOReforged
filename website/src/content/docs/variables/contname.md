---
title: "#ContName"
description: "Returns the name of currently selected container/gump."
kind: variable
category: container
access: ro
type: string
needsClient: true
source: wiki
---

The #contName system variable determines the name of the currently selected container/gump. The values that have been found so far are included in the table below. It may not be comprehensive, and Freeshards can and often do include custom gumps that will show up in this variable.

| Value | Description |
|----|----|
| stack_gump | comes up for amount input when dragging a stack |
| drag_gump | when something is dragged on the cursor |
| paperdoll_gump | Gump that shows your character's paperdoll. |
| status_gump | Gump that displays all your character's information. |
| skill_gump | The list gump that shows all your character's skills. |
| text_gump | from a journal open. |
| YesNo_gump | from a logout. |
| OptionsGump | Gump that is displayed when the Options button is pressed on the paperdoll. |
| generic_gump | The gump that is displayed by clicking the help button on the paperdoll, runebooks, and crafting menus to name a few. |
| missile_gump | seems to be an intermediate/transitional status, shows up when something is flying through the air. |
| normal_gump | seen with: chat screen and the shard selection screen. |
| container_gump | clicking on any item that acts as a container that holds other items will bring up this gump. |
| MainMenu_gump | ? |
| waiting_gump | this one comes up for stuff like bad password. Informational Gump. |
| login_gump | The login screen gump, where you type in your username and password. |
| dumb_gump | Gump for individual drops of snow or rain. It can interfear with scripts that are looking for other gumps, so if you want to prevent it from showing up you can use the UOA or Razer weather filter. |
| GameAreaEdgeGump | very quick, hard to catch, name might be wrong. |
| radar_gump | The map. |
| DamageNumbers_gump | comes up when doing damage to a target. Only available on AoS enabled clients/shards. |
| skillicon_gump | The rectangular gump with a skill's name in it that you can drag from the skill list gump. |
| spellicon_gump | Any one of the square spell icon's that you can drag from a spell book. |
| party_gump | The party system control menu gump. |
| profile_gump | The scroll that you can type information about yourself into, or display information that others have typed about themself if it's from another person. |
| combat_ability_book_gump | Any one of the square combat move icon's that you can drag from the combat book on your character's paperdoll. |
| spellbook_gump | The gump that opens when you open a spell book. |
| Course_gump | Treasure Map gump. |
| Bill_gump | Buy/Sell gump. |
| hue_gump | gump that allows you to set a color. most commonly seen when you set the color of a dye tub. |
| CharCreation_gump | character creation screen gump. |
| ListBoxControl_gump | it can be found on option gump, and the character creation gump, to name a couple. you need to actually select the control in order to see this gump. |
| resize_gump | Seen when resizing other gumps such as the journal, skill gump, etc... |
| map_gump | Character creation screen, when you choose the city to you wish to start in. |
| CONTEXT_HELP | Codex of Wisdom Gump. |

Known contName Values

:::note
EasyUO currently only holds information in the #cont\* on the "top most" gump. This means that the last gump that was opened or moved in any way is what EUO is reporting.
:::

## Example

```euo
...
if #contName = login_gump
     gosub login
......
```
