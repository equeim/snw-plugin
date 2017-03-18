/*
 * xfce4-snw-plugin
 * Copyright (C) 2015-2017 Alexey Rochev <equeim@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace StatusNotifier {
    private Gtk.Orientation get_orientation(uint orient) {
        switch (orient) {
        case MatePanel.AppletOrient.UP:
        case MatePanel.AppletOrient.DOWN:
            return Gtk.Orientation.HORIZONTAL;
        }
        return Gtk.Orientation.VERTICAL;
    }

    private bool factory_callback(MatePanel.Applet applet, string iid) {
        if (iid != "SNWApplet") {
            return false;
        }

        //applet.flags = MatePanel.AppletFlags.HAS_HANDLE;
        applet.flags = MatePanel.AppletFlags.HAS_HANDLE | MatePanel.AppletFlags.EXPAND_MINOR;

        var widget = new Widget(get_orientation(applet.orient), (int) applet.size, applet);

        applet.change_orient.connect((orient) => {
            widget.orientation = get_orientation(orient);
            widget.update_size();
        });

        applet.change_size.connect((size) => {
            widget.size = size;
            widget.update_size();
        });

        applet.add(widget);
        
        applet.show_all();

        return true;
    }
}

void main(string[] args) {
    Gtk.init(ref args);
    MatePanel.Applet.factory_main("SNWAppletFactory", true, typeof (MatePanel.Applet), StatusNotifier.factory_callback);
}
