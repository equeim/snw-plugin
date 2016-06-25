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
    private class Widget : Gtk.Box {
        private Plugin plugin;
        private Watcher watcher;
        private GenericArray<Button> buttons;
        private Gtk.DrawingArea handle;

        public Widget(Plugin plugin) {
            this.plugin = plugin;

            watcher = new Watcher(plugin.dbus_connection);
            buttons = new GenericArray<Button>();

            Gtk.rc_parse_string("""
                                style "button-style"
                                {
                                    GtkWidget::focus-line-width = 0
                                    GtkWidget::focus-padding = 0
                                    GtkButton::inner-border = {0,0,0,0}
                                }
                                widget_class "*<StatusNotifierButton>" style "button-style"
                                """);

            handle = new Gtk.DrawingArea();
            handle.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
            handle.expose_event.connect(draw_handle);
            pack_start(handle);

            plugin.size_changed.connect(change_size);
            plugin.orientation_changed.connect(change_orientation);

            watcher.item_added.connect(add_button);
            watcher.item_removed.connect(remove_button);
        }

        private void add_button(string bus_name, string object_path) {
            try {
                var button = new Button(bus_name, object_path, plugin);
                buttons.add(button);
                pack_start(button);
            } catch {
                watcher.remove_item(bus_name);
            }
        }

        private void remove_button(int index) {
            remove(buttons.data[index]);
            buttons.remove_index(index);
        }

        private bool change_size(int size) {
            if (orientation == Gtk.Orientation.HORIZONTAL) {
                handle.set_size_request(8, size);
            } else {
                handle.set_size_request(size, 8);
            }

            foreach (var button in buttons.data) {
                button.change_size(size);
            }

            return true;
        }

        private void change_orientation(Gtk.Orientation new_orientation) {
            orientation = new_orientation;
            change_size(plugin.size);
        }

        private bool draw_handle(Gdk.EventExpose event) {
            Gtk.paint_handle(handle.style,
                             handle.window,
                             handle.get_state(),
                             Gtk.ShadowType.NONE,
                             handle.allocation,
                             handle,
                             null,
                             0,
                             0,
                             handle.allocation.width,
                             handle.allocation.height,
                             (orientation == Gtk.Orientation.HORIZONTAL) ? Gtk.Orientation.VERTICAL
                                                                         : Gtk.Orientation.HORIZONTAL);
            return false;
        }
    }
}
