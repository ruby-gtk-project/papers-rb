# frozen_string_literal: true

require 'adwaita'

# ThumbnailItem is one row of the thumbnails sidebar's model: a page's label,
# the thumbnail painted for it, and the bookkeeping that keeps the two in
# step.
#
# Ported from upstream's shell/src/thumbnail_item.rs, which is a GObject with
# four properties and no behaviour of its own. It is a GLib::Object here for
# the same reason it is one there: a Gio::ListStore can only hold GObjects,
# and the GridView's factory binds its widgets to these properties.
#
class ThumbnailItem < GLib::Object
  type_register

  install_property(
    GLib::Param::String.new(
      'text',
      'Text',
      "The page's label",
      nil,
      GLib::Param::READWRITE,
    ),
  )

  # Gdk::Paintable is an interface, and the Ruby bindings expose it as a
  # module rather than a class a Param::Object will take, so the property is
  # declared over GLib::Object. Anything implementing Gdk::Paintable — the
  # Gdk::Texture a render job produces — is one.
  install_property(
    GLib::Param::Object.new(
      'paintable',
      'Paintable',
      'The rendered thumbnail',
      GLib::Object,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Object.new(
      'binding',
      'Binding',
      'The property binding holding this item to its widget',
      GLib::Binding,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Object.new(
      'job',
      'Job',
      'The thumbnail render job for this page',
      GLib::Object,
      GLib::Param::READWRITE,
    ),
  )

  attr_reader :text, :paintable, :binding, :job

  def text=(text)
    @text = text
    notify('text')
  end

  def paintable=(paintable)
    @paintable = paintable
    notify('paintable')
  end

  # The binding is dropped when the row is recycled, so the item stops
  # pushing its thumbnail into a widget that is now showing another page.
  def binding=(binding)
    @binding = binding
    notify('binding')
  end

  # The render job is held so that recycling the row can cancel it.
  def job=(job)
    @job = job
    notify('job')
  end
end
