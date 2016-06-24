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
    public class WatcherConnector : Object {
        public signal void item_added(string service, string object_path);
        public signal void item_removed(int index);
    }

    [DBus (name = "org.kde.StatusNotifierWatcher")]
    public class Watcher : Object {
        public WatcherConnector connector;

        private Array<string> _registered_status_notifier_items;
        private Array<string> object_paths;
        private Array<uint> watcher_ids;

        public Watcher() {
            connector = new WatcherConnector();

            _registered_status_notifier_items = new Array<string>();
            object_paths = new Array<string>();
            watcher_ids = new Array<uint>();

            Bus.own_name_on_connection(StatusNotifier.DBusConnection,
                                            "org.kde.StatusNotifierWatcher",
                                            BusNameOwnerFlags.NONE,
                                            on_name_acquired,
                                            on_name_lost);
        }

        //
        // DBus Properties
        //
        public bool is_status_notifier_host_registered { get { return true; } }
        public int protocol_version { get { return 0; } }

        public string[] registered_status_notifier_items { get { return _registered_status_notifier_items.data; } }

        //
        // DBus Methods
        //
        public void register_status_notifier_item(string bus_name, BusName sender) {
            string object_path = "/StatusNotifierItem";
            if (bus_name.contains("/")) {
                object_path = bus_name;
                bus_name = sender;
            }

            try {
                new StatusNotifier.Item.Proxy(bus_name, object_path);
            } catch (DBusError error) {
                return;
            }

            for (int i = 0; i < _registered_status_notifier_items.length; i++) {
                if (_registered_status_notifier_items.index(i) == bus_name) {
                    try {
                        new StatusNotifier.Item.Proxy(bus_name,
                                                      object_paths.index(i));
                        return;
                    } catch (DBusError error) {
                        remove_item(null, bus_name);
                        break;
                    }
                }
            }

            _registered_status_notifier_items.append_val(bus_name);
            object_paths.append_val(object_path);

            watcher_ids.append_val(Bus.watch_name(BusType.SESSION,
                                                       bus_name,
                                                       BusNameWatcherFlags.NONE,
                                                       () => {},
                                                       remove_item));

            status_notifier_item_registered(bus_name);
            connector.item_added(bus_name, object_path);
        }

        public void register_status_notifier_host(string bus_name) {}

        //
        // DBus Signals
        //
        public signal void status_notifier_host_registered();
        public signal void status_notifier_item_registered(string bus_name);
        public signal void status_notifier_item_unregistered(string bus_name);

        //
        // Private Methods
        //
        private void on_name_acquired() {
            try {
                StatusNotifier.DBusConnection.register_object("/StatusNotifierWatcher", this);
            } catch (IOError e) {
                stderr.printf("Could not register service\n");
            }
        }

        private void on_name_lost() {
            stderr.printf("Could not acquire name");
        }

        private void remove_item(DBusConnection? connection, string bus_name) {
            for (int i = 0; i < _registered_status_notifier_items.length; i++) {
                if (_registered_status_notifier_items.index(i) == bus_name) {
                    Bus.unwatch_name(watcher_ids.index(i));
                    watcher_ids.remove_index(i);
                    _registered_status_notifier_items.remove_index(i);
                    object_paths.remove_index(i);
                    status_notifier_item_unregistered(bus_name);
                    connector.item_removed(i);
                    break;
                }
            }
        }
    }
}
