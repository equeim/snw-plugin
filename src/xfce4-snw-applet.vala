using GLib;

public class SNWPlugin : Xfce.PanelPlugin {
    public override void @construct() {
        StatusNotifierWidget widget = new StatusNotifierWidget(this);
        add(widget);
        add_action_widget(widget);
        widget.show_all();

        destroy.connect(() => {
            Gtk.main_quit();
        });
    }
}

[ModuleInit]
public Type xfce_panel_module_init (TypeModule module) {
    return typeof (SNWPlugin);
}
