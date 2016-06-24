/*
 * xfce4-snw-plugin
 * Copyright (C) 2015 Alexey Rochev <equeim@gmail.com>
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
    public class Widget : Gtk.Box {
        Xfce.PanelPlugin plugin;
        StatusNotifier.Watcher watcher;
        Array<StatusNotifier.Button> buttons;
        Gtk.DrawingArea handle;

        public Widget(Xfce.PanelPlugin plugin) {
            this.plugin = plugin;

            watcher = new StatusNotifier.Watcher();
            buttons = new Array<StatusNotifier.Button>();

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

            watcher.connector.item_added.connect(add_button);
            watcher.connector.item_removed.connect(remove_button);
        }

        void add_button(string bus_name, string object_path) {
            StatusNotifier.Button button = new StatusNotifier.Button(bus_name, object_path, plugin);
            buttons.append_val(button);
            pack_start(button);
        }

        void remove_button(int index) {
            remove(buttons.index(index));
            buttons.remove_index(index);
        }

        bool change_size(int size) {
            if (orientation == Gtk.Orientation.HORIZONTAL) {
                    handle.set_size_request(8, size);
            } else {
                    handle.set_size_request(size, 8);
            }

            foreach (StatusNotifier.Button button in buttons.data) {
                button.change_size(size);
            }

            return true;
        }

        void change_orientation(Gtk.Orientation new_orientation) {
            orientation = new_orientation;
            change_size(plugin.size);
        }

        bool draw_handle(Gdk.EventExpose event) {
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
                                get_handle_orientation());
            return false;
        }

        Gtk.Orientation get_handle_orientation() {
            if (orientation == Gtk.Orientation.HORIZONTAL) {
                return Gtk.Orientation.VERTICAL;
            }
            return Gtk.Orientation.HORIZONTAL;
        }
    }
}
