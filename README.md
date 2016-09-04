# snw-plugin
Plugin for xfce4-panel and mate-panel to show StatusNotifierItems (also known as AppIndicators)
## Installation
Dependencies:
* Python (build only)
* Vala (build only)
* GTK+ 2
* libdbusmenu-gtk2
* xfce4-panel or mate-panel

### Building
For xfce4-panel:
```
./waf configure
./waf build
./waf install
```
For mate-panel:
```
./waf configure --mate
./waf build
./waf install
```
