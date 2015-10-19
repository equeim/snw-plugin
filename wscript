def options(context):
    context.load("compiler_c gnu_dirs vala")


def configure(context):
    context.load("compiler_c gnu_dirs intltool vala")

    context.check_cfg(package="dbusmenu-gtk-0.4", args="--libs --cflags")
    context.check_cfg(package="libxfce4panel-1.0", args="--libs --cflags")


def build(context):
    context.shlib(
        target="snw",
        packages="Dbusmenu-0.4 DbusmenuGtk-0.4 libxfce4panel-1.0",
        vapi_dirs="src/vapi",
        uselib="DBUSMENU-GTK-0.4 LIBXFCE4PANEL-1.0",
        source=[
            "src/qrichtextparser.vala",
            "src/statusnotifierbutton.vala",
            "src/statusnotifieritem.vala",
            "src/statusnotifierwatcher.vala",
            "src/statusnotifierwidget.vala",
            "src/xfce4-snw-plugin.vala"
        ],
        install_binding=False,
        install_path="${LIBDIR}/xfce4/panel/plugins"
    )

    context(
        features="intltool_in",
        podir="po",
        style="desktop",
        source="data/snw.desktop.in",
        target="snw.desktop",
        install_path="${DATADIR}/xfce4/panel/plugins"
    )
