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

using GLib;

//
// DBus Interface
//
[DBus (name = "org.kde.StatusNotifierWatcher")]
public class StatusNotifierWatcher : Object {

    public StatusNotifierWatcher() {
        connector = new Connector();

        _registered_status_notifier_items = new Array<string>();
        object_paths = new Array<string>();
        watcher_ids = new Array<uint>();

        Bus.own_name(BusType.SESSION,
                    "org.kde.StatusNotifierWatcher",
                    BusNameOwnerFlags.NONE,
                    on_bus_aquired,
                    () => {},
                    () => stderr.printf("Could not aquire name\n"));
    }

    //
    // DBus Properties
    //
    public bool is_status_notifier_host_registered { get { return true; } }
    public int protocol_version { get { return 0; } }

    Array<string> _registered_status_notifier_items;
    public string[] registered_status_notifier_items { get { return _registered_status_notifier_items.data; } }

    //
    // DBus Methods
    //
    public void register_status_notifier_item(string service, GLib.BusName sender) {
        string object_path = "/StatusNotifierItem";
        if (service.contains("/")) {
            object_path = service;
            service = sender;
        }

        for (int i = 0; i < registered_status_notifier_items.length; i++) {
            if (service == registered_status_notifier_items[i]) {
                StatusNotifierItem ping_item = Bus.get_proxy_sync(BusType.SESSION,
                                                                  service,
                                                                  object_paths.index(i));
                if (ping_item.id == null) {
                    remove_item(null, service);
                    break;
                } else {
                    return;
                }
            }
        }

        _registered_status_notifier_items.append_val(service);
        object_paths.append_val(object_path);

        watcher_ids.append_val(Bus.watch_name(BusType.SESSION,
                                    service,
                                    BusNameWatcherFlags.NONE,
                                    () => {},
                                    remove_item));

        status_notifier_item_registered(service);
        connector.item_added(service, object_path);
    }

    public void register_status_notifier_host(string service) {

    }

    //
    // DBus Signals
    //
    public signal void status_notifier_host_registered();
    public signal void status_notifier_item_registered(string service);
    public signal void status_notifier_item_unregistered(string service);

    //
    // Private Methods
    //
    private void on_bus_aquired(DBusConnection connection) {
        try {
            connection.register_object ("/StatusNotifierWatcher", this);
        } catch (IOError e) {
            stderr.printf ("Could not register service\n");
        }
    }

    private void remove_item(DBusConnection? connection, string service) {
        for (int i = 0; i < registered_status_notifier_items.length; i++) {
            if (service == registered_status_notifier_items[i]) {
                Bus.unwatch_name(watcher_ids.index(i));
                watcher_ids.remove_index(i);
                _registered_status_notifier_items.remove_index(i);
                object_paths.remove_index(i);
                status_notifier_item_unregistered(service);
                connector.item_removed(i);
                break;
            }
        }
    }

    Array<string> object_paths;
    Array<uint> watcher_ids;
    public Connector connector;
}

public class Connector : Object {
    public signal void item_added(string service, string object_path);
    public signal void item_removed(int index);
}
