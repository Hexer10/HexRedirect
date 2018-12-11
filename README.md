# Installation
1. [Download](https://github.com/Hexer10/HexRedirect/archive/master.zip) this repo
2. To install the sourcemod plugin just merge the `addons/sourcemod` located in `GameServer/` folder with yours.
3. To install the php script, just move it(`WebServer/redirect.php`) to your webserver.
4. Configure the php script, editing the `redirect.php`, following the instructions.
5. Set your `motd.txt` to redirect to the php script.

# Configuration
* The plugin configuration is located in `sourcemod/configs/hextags.cfg`
* The patter is `"command"  "url"`
* Make sure to include the full url with the scheme as well(`https` or `http`).

Example
```
"HexRedirect"
{
    "google"    "https://www.google.com/"
    "!plugins" "https://forums.alliedmods.net/forumdisplay.php?f=123"
    "zombie" "steam://connect/127.0.0.1:27015" //Your server IP, this will make the player join there
}
```

# How this works
When the user types that are listed in the cfg its ip is saved in the database, and when the user open the motd page, it will check if the given IP has any url to be redirected, if not it will just send to the set homepage.

I know that is could not be the most reliable way (especially if two player have the same IP), but it's the only the I could figure without having the user to copy-paste the url.

# Video example 
[![Watch the video](https://img.youtube.com/vi/TW_yxPcodhk/maxresdefault.jpg)](https://www.youtube.com/watch?v=TW_yxPcodhk)

 
