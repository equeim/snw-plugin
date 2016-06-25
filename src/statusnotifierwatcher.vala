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
    private class WatcherBase : Object {
        protected DBusConnection dbus_connection;

        protected Array<string> _registered_status_notifier_items;
        protected Array<string> object_paths;
        protected Array<uint> watcher_ids;

        public signal void item_added(string bus_name, string object_path);
        public signal void item_removed(int index);

        public WatcherBase(DBusConnection connection) {
            dbus_connection = connection;

            _registered_status_notifier_items = new Array<string>();
            object_paths = new Array<string>();
            watcher_ids = new Array<uint>();
        }

        public void remove_item(string bus_name) {
            for (int i = 0; i < _registered_status_notifier_items.length; i++) {
                if (_registered_status_notifier_items.index(i) == bus_name) {
                    Bus.unwatch_name(watcher_ids.index(i));
                    watcher_ids.remove_index(i);
                    _registered_status_notifier_items.remove_index(i);
                    object_paths.remove_index(i);
                    item_removed(i);
                    break;
                }
            }
        }
    }

    [DBus (name = "org.kde.StatusNotifierWatcher")]
    private class Watcher : WatcherBase {
        public bool is_status_notifier_host_registered { get { return true; } }
        public int protocol_version { get { return 0; } }

        public string[] registered_status_notifier_items { get { return _registered_status_notifier_items.data; } }

        public signal void status_notifier_host_registered();
        public signal void status_notifier_item_unregistered(string bus_name);
        public signal void status_notifier_item_registered(string bus_name);

        public Watcher(DBusConnection connection) {
            base(connection);
            Bus.own_name_on_connection(dbus_connection,
                                       "org.kde.StatusNotifierWatcher",
                                       BusNameOwnerFlags.NONE,
                                       () => {
                                           try {
                                               dbus_connection.register_object("/StatusNotifierWatcher", this);
                                           } catch (IOError e) {
                                               stderr.printf("Could not register service\n");
                                           }
                                       },
                                       () => stderr.printf("Could not acquire name\n"));
        }

        public void register_status_notifier_item(string bus_name, BusName sender) {
            string object_path;
            if (bus_name.contains("/")) {
                object_path = bus_name;
                bus_name = sender;
            } else {
                object_path = "/StatusNotifierItem";
            }

            try {
                ItemProxy.check_existence(dbus_connection, bus_name, object_path);
            } catch {
                return;
            }

            foreach (var item in _registered_status_notifier_items.data) {
                if (item == bus_name) {
                    return;
                }
            }

            _registered_status_notifier_items.append_val(bus_name);
            object_paths.append_val(object_path);

            watcher_ids.append_val(Bus.watch_name(BusType.SESSION,
                                                  bus_name,
                                                  BusNameWatcherFlags.NONE,
                                                  null,
                                                  (connection, bus_name) => {
                                                      remove_item(bus_name);
                                                      status_notifier_item_unregistered(bus_name);
                                                  }));

            item_added(bus_name, object_path);
            status_notifier_item_registered(bus_name);
        }

        public void register_status_notifier_host(string bus_name) { }
    }
}
