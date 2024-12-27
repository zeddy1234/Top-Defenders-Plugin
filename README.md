
# Top Defenders

Top Defenders plugin used on Zeddy currently.

I decided to open source this as CSGO is coming to a close soon, and figured open sourcing this would be in the best interest for the future developement of CS2. I plan to port this plugin to CS2 once a modding environment is finally decided on.

> [!NOTE]
> Use Kxnrl's [CSGO-HtmlHud](https://github.com/Kxnrl/CSGO-HtmlHud) plugin as a replacement for `UIManager`.

## Features

- Display top defender stats via warmup text box
- Commands to check player stats
- Real time defender status updates for other plugins to retrieve stats mid-game

## Commands

- `sm_tdrank` - Prints your current defender rank
- `sm_tdfind [rank|name]` - Prints the defender stats of a player
 
## ConVars

- `sm_topdefender_dmgmin` - Minimum amount of damage needed to be displayed (Integer, Def. 5000)
- `sm_topdefender_mindmgreceived` - Minimum amount of damage taken needed to be displayed (Integer, Def. 10000)
- `sm_topdefender_rate` - How often top defender ranking is updated (Float, Def. 10.0)
