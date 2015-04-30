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

public class StatusNotifierWidget : Gtk.Box {

    public StatusNotifierWidget(SNWPlugin plugin) {
        this.plugin = plugin;
        plugin.size_changed.connect(change_size);
        plugin.orientation_changed.connect(change_orientation);
        watcher = new StatusNotifierWatcher();

        watcher.connector.item_added.connect(add_button);
        watcher.connector.item_removed.connect(remove_button);

        buttons = new Array<StatusNotifierButton>();

#if !GTK3
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

        handle = new Gtk.DrawingArea();
        handle.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
#if GTK3
        handle.draw.connect(draw_handle);
#else
        handle.expose_event.connect(draw_handle);
#endif
        pack_start(handle);
    }

    void add_button(string service, string object_path) {
        StatusNotifierButton button = new StatusNotifierButton(service, object_path, plugin);
        buttons.append_val(button);
        pack_start(button);
        button.show_all();
        button.update_icon();
    }

    void remove_button(int index) {
        remove(buttons.index(index));
        buttons.remove_index(index);
    }

    bool change_size(int size) {
        if (orientation == Gtk.Orientation.HORIZONTAL)
	        handle.set_size_request(8, size);
        else
	        handle.set_size_request(size, 8);

        for(int i = 0; i < buttons.length; i++) {
            buttons.index(i).change_size(size);
        }
        return true;
    }

    void change_orientation(Gtk.Orientation new_orientation) {
        orientation = new_orientation;
        change_size(plugin.size);
    }

#if GTK3
    bool draw_handle(Cairo.Context context) {
        handle.get_style_context().render_handle(context,
                                                0,
                                                0,
                                                handle.get_allocated_width(),
                                                handle.get_allocated_height());
#else
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
#endif
        return false;
    }

#if !GTK3
    Gtk.Orientation get_handle_orientation() {
        if (orientation == Gtk.Orientation.HORIZONTAL)
            return Gtk.Orientation.VERTICAL;
        return Gtk.Orientation.HORIZONTAL;
    }
#endif

    SNWPlugin plugin;
    Array<StatusNotifierButton> buttons;
    Gtk.DrawingArea handle;
    StatusNotifierWatcher watcher;
}
