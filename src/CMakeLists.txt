vala_precompile(VALA_C
    xfce4-snw-applet.vala
    statusnotifierbutton.vala
    statusnotifieritem.vala
    statusnotifierwatcher.vala
    statusnotifierwidget.vala
PACKAGES 
    gtk+-2.0
	Dbusmenu-0.4
    DbusmenuGtk-0.4
CUSTOM_VAPIS
    vapi/libxfce4panel-1.0.vapi
)

add_library(snw SHARED ${VALA_C})
include_directories(${GTK+_INCLUDE_DIRS} ${LIBXFCE4PANEL_INCLUDE_DIRS} ${DBUSMENU_GTK_INCLUDE_DIRS})
target_link_libraries(snw ${GTK+_LIBRARIES} ${LIBXFCE4PANEL_LIBRARIES} ${DBUSMENU_GTK_LIBRARIES})

install(TARGETS snw DESTINATION lib/xfce4/panel/plugins)
