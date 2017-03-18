# snw-plugin
Plugin for xfce4-panel and mate-panel to show StatusNotifierItems (also known as AppIndicators)

## Installation
Dependencies:
* Python (build only)
* Vala (build only)
* intltool (build only)
* libdbusmenu-gtk2 or libdbusmenu-gtk3
* xfce4-panel or mate-panel

### Building
```
# xfce4-panel GTK+ 2
./waf configure

# xfce4-panel GTK+ 3
./waf configure --gtk3

# mate-panel GTK+ 2
./waf configure --mate

# mate-panel GTK+ 3
./waf configure --mate --gtk3

./waf build
./waf install
```

### Distributions
#### Arch Linux
[xfce4-snw-plugin](https://aur.archlinux.org/packages/xfce4-snw-plugin)
[mate-snw-plugin](https://aur.archlinux.org/packages/mate-snw-plugin)

#### Gentoo
Ebuilds are available in [my overlay](https://github.com/equeim/equeim-overlay).
