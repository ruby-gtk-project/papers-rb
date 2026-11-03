# frozen_string_literal: true

require 'adwaita'

# ViewCursor names the cursors the document view puts on itself.
#
# Ported from upstream's libview/pps-view-cursor.c, which is a lookup table
# from the PpsViewCursor enum to the CSS cursor names GTK understands, plus
# NULL for the normal cursor (which in GTK means "inherit from the parent").
#
module ViewCursor
  NORMAL = :normal
  IBEAM = :ibeam
  LINK = :link
  WAIT = :wait
  HIDDEN = :hidden
  DRAG = :drag
  ADD = :add

  # In upstream's enum order, so a numeric cursor from a port of
  # pps-view.c still resolves to the same name.
  ALL = [NORMAL, IBEAM, LINK, WAIT, HIDDEN, DRAG, ADD].freeze

  NAMES = {
    NORMAL => nil,
    IBEAM  => 'text',
    LINK   => 'pointer',
    WAIT   => 'wait',
    HIDDEN => 'none',
    DRAG   => 'grabbing',
    ADD    => 'crosshair',
  }.freeze

  # Upstream indexes its table by the enum value and answers NULL for anything
  # past the end of it; an unknown cursor gets the same answer here, and a
  # plain integer is read as a position in the enum.
  def self.name(cursor)
    cursor.is_a?(Integer).then do |numeric|
      if numeric
        NAMES.fetch(ALL.fetch(cursor, nil), nil)
      else
        NAMES.fetch(cursor, nil)
      end
    end
  end

  # Puts the cursor on a widget. `nil` is passed through rather than turned
  # into a cursor object, because that is how GTK spells "no cursor of my own".
  def self.apply(widget, cursor)
    widget.set_cursor_from_name(name(cursor))
  end
end
