project(xfce4-snw-plugin)
cmake_minimum_required(VERSION 2.6)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

include(UseVala)

option(USE_GTK3 Off)

find_package(Vala)
find_package(PkgConfig)

if(USE_GTK3)
    pkg_check_modules(GTK+ REQUIRED gtk+-3.0)
    pkg_check_modules(LIBXFCE4PANEL REQUIRED libxfce4panel-2.0)
    pkg_check_modules(DBUSMENU_GTK REQUIRED dbusmenu-gtk3-0.4)
else()
    pkg_check_modules(GTK+ REQUIRED gtk+-2.0)
    pkg_check_modules(LIBXFCE4PANEL REQUIRED libxfce4panel-1.0)
    pkg_check_modules(DBUSMENU_GTK REQUIRED dbusmenu-gtk-0.4)
endif()

add_subdirectory(data)
add_subdirectory(src)
