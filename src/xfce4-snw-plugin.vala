/*
 * xfce4-snw-plugin
 * Copyright (C) 2015-2016 Alexey Rochev <equeim@gmail.com>
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
    private class Plugin : Xfce.PanelPlugin {
        public DBusConnection dbus_connection;

        public override void @construct() {
            try {
                dbus_connection = Bus.get_sync(BusType.SESSION, null);
            } catch (IOError error) {
                stderr.printf("%s\n", error.message);
            }

            var widget = new Widget(this);
            add(widget);
            add_action_widget(widget);
            widget.show_all();
        }
    }
}

[ModuleInit]
public Type xfce_panel_module_init(TypeModule module) {
    return typeof (StatusNotifier.Plugin);
}
