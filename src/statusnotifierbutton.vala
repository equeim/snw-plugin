using GLib;

public class StatusNotifierButton : Gtk.ToggleButton {
    
    public StatusNotifierButton(string service, string object_path, SNWPlugin plugin) {
        set_relief(Gtk.ReliefStyle.NONE);
        this.service = service;
        this.object_path = object_path;
        
        this.plugin = plugin;

        item = Bus.get_proxy_sync(BusType.SESSION,
                            service,
                            object_path);
        
        int size = plugin.get_size();
        set_size_request(size, size);
        
        icon_size = size;
        if (icon_size < 22)
            icon_size = 16;
        else if (icon_size < 32)
            icon_size = 22;
        else if (icon_size < 48)
            icon_size = 32;
        icon_theme = Gtk.IconTheme.get_default();
        icon_theme.prepend_search_path(item.icon_theme_path);
        Gdk.Pixbuf icon_pixbuf = icon_theme.load_icon(item.icon_name, icon_size, 0);
        icon = new Gtk.Image.from_pixbuf(icon_pixbuf);
        add(icon);
        
        menu = new DbusmenuGtk.Menu(service, item.menu);
        menu.deactivate.connect(hide_menu);
        
        if (item.tool_tip.title.length != 0) {
            tooltip_text = item.tool_tip.title;
        } else {
            tooltip_text = item.title;
        }
        
        //
        // Signal connections
        //
        
        button_press_event.connect(button_pressed);
        scroll_event.connect(wheel_rotated);
        
        item.new_tool_tip.connect(update_tooltip);
        item.new_icon.connect(update_icon);
    }
    
    //
    // Signal handlers
    //
    
    void hide_menu() {
        if (active) {
            active = false;
        }
    }
    
    bool button_pressed(Gdk.EventButton event) {
        if (event.button == 1) {
            active = true;
            menu.reposition();
            menu.popup(null,
                    null,
                    (menu, out x, out y, out push_in) => {
                        Xfce.PanelPlugin.position_menu(menu, out x, out y, out push_in, plugin);
                    },
                    event.button,
                    event.time);
        } else if (event.button == 2) {
            item.activate((int) event.x_root, (int) event.y_root);
        } else if (event.button == 3) {
            plugin.button_press_event(event);
        }
        return false;
    }
    
    bool wheel_rotated(Gdk.EventScroll event) {
        switch (event.direction) {
        case Gdk.ScrollDirection.LEFT:
            item.scroll(-120, "horizontal");
            break;
        case Gdk.ScrollDirection.RIGHT:
            item.scroll(120, "horizontal");
            break;
        case Gdk.ScrollDirection.DOWN:
            item.scroll(-120, "vertical");
            break;
        case Gdk.ScrollDirection.UP:
            item.scroll(120, "vertical");
            break;
        }
        return false;
    }
    
    void update_tooltip() {
        StatusNotifierItem new_item = Bus.get_proxy_sync(BusType.SESSION,
                            service,
                            object_path);
        if (new_item.tool_tip.title.length != 0) {
            tooltip_text = new_item.tool_tip.title;
        } else {
            tooltip_text = new_item.title;
        }
    }
    
    void update_icon() {
        StatusNotifierItem new_item = Bus.get_proxy_sync(BusType.SESSION,
                            service,
                            object_path);
        icon_theme.prepend_search_path(new_item.icon_theme_path);
        Gdk.Pixbuf icon_pixbuf = icon_theme.load_icon(new_item.icon_name, icon_size, 0);
        remove(icon);
        icon = new Gtk.Image.from_pixbuf(icon_pixbuf);
        add(icon);
        icon.show();
    }
    
    public void change_size(int size) {
        StatusNotifierItem item;
        item = Bus.get_proxy_sync(BusType.SESSION,
                            service,
                            object_path);
        
        icon_size = size;
        if (icon_size < 22)
            icon_size = 16;
        else if (icon_size < 32)
            icon_size = 22;
        else if (icon_size < 48)
            icon_size = 32;
        icon_theme.prepend_search_path(item.icon_theme_path);
        Gdk.Pixbuf icon_pixbuf = icon_theme.load_icon(item.icon_name, icon_size, 0);
        remove(icon);
        icon = new Gtk.Image.from_pixbuf(icon_pixbuf);
        add(icon);
        icon.show();
        
        set_size_request(size, size);
    }
    
    //
    // Private members
    //
    
    SNWPlugin plugin;
    StatusNotifierItem item;
    string service;
    string object_path;
    DbusmenuGtk.Menu menu;
    Gtk.Image icon;
    Gtk.IconTheme icon_theme;
    int icon_size;
}
