import gi
from gi.repository import Gio

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk


import jessentials

# The path arrives as one argv element and is used as data, unchanged.
#
# It used to arrive quoted ("--file='/path'") because the caller ran the
# helper through a shell, and this line stripped the quotes again. The
# caller no longer adds them and no longer uses a shell, so stripping them
# here would only corrupt a path that legitimately ends in a quote
# character.
file_path = jessentials.get_value_from_arguments("file")

info = Gio.File.new_for_path(file_path).query_info('standard::icon', Gio.FileQueryInfoFlags.NONE, None)
icon = info.get_icon()

if icon:
    theme = Gtk.IconTheme.get_default()
    size = 48
    icon_name = info.get_icon().get_names()[0]
    icon_path = theme.lookup_icon(icon_name, size, 0).get_filename()
    print(icon_path)