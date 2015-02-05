project(xfce4-snw-plugin)
cmake_minimum_required(VERSION 2.6)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)

include(UseVala)

find_package(Vala)
find_package(PkgConfig)

pkg_check_modules(GTK+ REQUIRED gtk+-2.0)
pkg_check_modules(LIBXFCE4PANEL REQUIRED libxfce4panel-1.0)
pkg_check_modules(DBUSMENU_GTK REQUIRED dbusmenu-gtk-0.4)

add_subdirectory(data)
add_subdirectory(src)

set(CPACK_SOURCE_PACKAGE_FILE_NAME ${PROJECT_NAME}-0.1)
set(CPACK_SOURCE_GENERATOR TXZ)
set(CPACK_SOURCE_IGNORE_FILES /build/;.gitignore;.*~;.git;.kdev4;temp)
INCLUDE(CPack)
