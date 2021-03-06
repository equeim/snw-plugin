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
    private class Widget : Gtk.Box {
        public DBusConnection dbus_connection;

        public int size { get; set; }

#if MATE
        private MatePanel.Applet applet;
#else
        private Plugin plugin;
#endif
        private Watcher watcher;
        private GenericArray<Button> buttons;
        private Gtk.DrawingArea handle;

#if MATE
        public Widget(Gtk.Orientation orientation, int size, MatePanel.Applet applet) {
#else
        public Widget(Gtk.Orientation orientation, int size, Plugin plugin) {
#endif
            this.orientation = orientation;
#if MATE
            this.applet = applet;
#else
            this.plugin = plugin;
#endif

            buttons = new GenericArray<Button>();

            try {
                dbus_connection = Bus.get_sync(BusType.SESSION, null);
            } catch (IOError error) {
                print_error(error.message);
            }

            watcher = new Watcher(dbus_connection);

#if GTK3
            var provider = new Gtk.CssProvider();
            try {
                provider.load_from_data("""
                                        .statusnotifierbutton {
                                            padding: 2px;
                                        }
                                        """);
                Gtk.StyleContext.add_provider_for_screen(get_screen(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            } catch (Error error) {
                print_error(error.message);
            }
#else
            Gtk.rc_parse_string("""
                                style "button-style"
                                {
                                    GtkWidget::focus-line-width = 0
                                    GtkWidget::focus-padding = 0
                                    GtkButton::inner-border = {0,0,0,0}
                                }
                                widget_class "*<StatusNotifierButton>" style "button-style"
                                """);
#endif

#if !MATE
            handle = new Gtk.DrawingArea();
            handle.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
#if !GTK3
            handle.expose_event.connect(() => {
                Gtk.paint_handle(handle.style,
                                 handle.window,
                                 handle.get_state(),
                                 Gtk.ShadowType.NONE,
                                 null,
                                 handle,
                                 null,
                                 0,
                                 0,
                                 handle.allocation.width,
                                 handle.allocation.height,
                                 (orientation == Gtk.Orientation.HORIZONTAL) ? Gtk.Orientation.VERTICAL
                                                                             : Gtk.Orientation.HORIZONTAL);
                return false;
            });
#endif // !GTK3
            pack_start(handle);
#endif // !MATE

            this.size = size;
            update_size();

            watcher.item_added.connect(add_button);
            watcher.item_removed.connect(remove_button);
        }

        public void update_size() {
#if !MATE
            if (orientation == Gtk.Orientation.HORIZONTAL) {
                handle.set_size_request(8, size);
            } else {
                handle.set_size_request(size, 8);
            }
#endif

            foreach (var button in buttons.data) {
                button.update_icon();
            }
        }

        private void add_button(string bus_name, string object_path) {
            try {
#if MATE
                var button = new Button(bus_name, object_path, this, applet);
#else
                var button = new Button(bus_name, object_path, this, plugin);
#endif
                buttons.add(button);
                pack_start(button);
            } catch (Error error) {
                print_error(error.message);
                watcher.remove_item(bus_name);
            }
        }

        private void remove_button(int index) {
            remove(buttons.data[index]);
            buttons.remove_index(index);
        }
    }
}
