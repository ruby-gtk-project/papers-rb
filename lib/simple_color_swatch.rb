# frozen_string_literal: true

require 'adwaita'

# SimpleColorSwatch is the round colour chip the annotation toolbars show on
# their colour buttons.
#
# Ported from upstream's shell/src/simple_color_swatch.rs, which is a
# Gtk.Widget subclass with a snapshot implementation: a rounded clip over the
# largest square the allocation holds, white underneath, and the colour over
# the white so a colour with alpha reads against a page rather than against
# the window.
#
# The Ruby bindings do not dispatch the snapshot vfunc to a subclass, so the
# drawing is the same drawing done through a Gtk::DrawingArea's draw function.
# The white underneath is kept for the reason upstream gives: most documents
# have a white background.
#
class SimpleColorSwatch < Gtk::DrawingArea
  type_register

  install_property(
    GLib::Param::Boxed.new(
      'color',
      'Color',
      'The colour the swatch shows',
      Gdk::RGBA,
      GLib::Param::READWRITE,
    ),
  )

  attr_reader :color

  def initialize
    super()
    @color = Gdk::RGBA.parse('#000000')
  end

  def build
    tap do |swatch|
      swatch.set_draw_func { |_area, context, width, height| draw(context, width, height) }
    end
  end

  # Upstream redraws on every colour change, and so does this.
  def color=(color)
    @color = color
    notify('color')
    queue_draw
  end

  private

    def draw(context, width, height)
      [width, height].min.then do |radius|
        circle(
          context,
          (width - radius) / 2.0,
          (height - radius) / 2.0,
          radius,
        )
        fill(context, Gdk::RGBA.parse('#ffffff'))
        circle(
          context,
          (width - radius) / 2.0,
          (height - radius) / 2.0,
          radius,
        )
        fill(context, @color)
      end
    end

    # The rounded rectangle upstream clips with, whose corner radii are the
    # side of the square — which is to say, a circle.
    def circle(context, x, y, diameter)
      context.new_path
      context.arc(
        x + (diameter / 2.0),
        y + (diameter / 2.0),
        diameter / 2.0,
        0,
        2 * Math::PI,
      )
    end

    def fill(context, color)
      context.set_source_rgba(
        color.red,
        color.green,
        color.blue,
        color.alpha,
      )
      context.fill
    end
end
