# frozen_string_literal: true

require 'adwaita'

# ViewColors supplies the selection and accent colours the view draws with.
#
# Ported from upstream's libview/pps-colors.c. The name is ViewColors, in
# lib/view_colors.rb, and not the mechanical Colors in lib/colors.rb, because
# both of those are taken: the `cairo` gem — which every GTK gem loads —
# does `require "colors"` and uses the `Colors` module the red-colors gem
# defines. A lib/colors.rb on the load path shadows that file, and the app
# then dies while loading GTK. Upstream's get_accent_color
# writes into caller-supplied GdkRGBA structs and leaves the foreground's
# alpha untouched (the struct arrives zeroed, so the foreground is
# transparent white); here each function returns a fresh Gdk::RGBA instead,
# and the foreground is spelled out with the same components.
#
module ViewColors
  # Upstream's HAVE_TRANSPARENT_SELECTION build guards get_selection_color.
  # The alphas it multiplies by are the two constants below.
  SELECTION_FOCUSED_ALPHA = 0.3
  SELECTION_UNFOCUSED_ALPHA = 0.1

  def self.accent_background_color
    Adwaita::StyleManager.default.accent_color_rgba
  end

  # White, with the alpha upstream leaves at its zeroed value.
  def self.accent_foreground_color
    Gdk::RGBA.new(
      1.0,
      1.0,
      1.0,
      0.0,
    )
  end

  # A focused view tints the selection with the accent colour; an unfocused one
  # tints it with the widget's own foreground colour, both heavily faded.
  def self.selection_color(widget)
    widget.state_flags.focus_within?.then do |focused|
      if focused
        faded(accent_background_color, SELECTION_FOCUSED_ALPHA)
      else
        faded(widget.color, SELECTION_UNFOCUSED_ALPHA)
      end
    end
  end

  def self.faded(color, factor)
    Gdk::RGBA.new(
      color.red,
      color.green,
      color.blue,
      color.alpha * factor,
    )
  end
end
