using GLib;

public class StatusNotifierWidget : Gtk.Box {
    
    public StatusNotifierWidget(SNWPlugin plugin) {
        this.plugin = plugin;
        plugin.size_changed.connect(change_size);
        this.watcher = new StatusNotifierWatcher();
        watcher.connector.item_added.connect(add_button);
        watcher.connector.item_removed.connect(remove_button);

        buttons = new Array<StatusNotifierButton>();
        items = new Array<StatusNotifierItem>();
        
        Gtk.rc_parse_string("""
                        style "showdesktop-button-style"
                        {
                        GtkWidget::focus-line-width = 0
                        GtkWidget::focus-padding = 0
                        GtkButton::inner-border = {0,0,0,0}
                        }
                        #widget "*.showdesktop-button" style "showdesktop-button-style"
                        widget_class "*<StatusNotifierButton>" style "showdesktop-button-style"
                        """);

    }
    
    public void add_button(string service, string object_path) {
        StatusNotifierButton button = new StatusNotifierButton(service, object_path, plugin);
        buttons.append_val(button);

        pack_start(button);
        button.show_all();
    }
    
    void remove_button(int index) {
        remove(buttons.index(index));
        buttons.remove_index(index);
        items.remove_index(index);
    }
    
    bool change_size(int size) {
        for(int i = 0; i < buttons.length; i++) {
            buttons.index(i).change_size(size);
        }
        return true;
    }
    
    private SNWPlugin plugin;
    private Array<StatusNotifierButton> buttons;
    private Array<StatusNotifierItem> items;
    private StatusNotifierWatcher watcher;
    
    //public int buttons_count { get { return buttons.length } }
}
