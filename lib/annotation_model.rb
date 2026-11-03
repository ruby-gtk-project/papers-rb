# frozen_string_literal: true

require 'adwaita'

# AnnotationModel holds the settings the annotation tools draw with: which
# tool is active, and each tool's radius, colour and font.
#
# Ported from upstream's libview/context/pps-annotation-model.c. It is a
# GObject there and a GLib::Object here, with the same property names, so the
# toolbars can still bind to it and listen for "notify::pen-color" and
# friends. The one place the shapes differ is the two tool properties: "tool"
# is an int in upstream's C as well (its PpsAnnotationTool enum has no GType),
# and "active-tool-str" is the string spelling the toolbar's radio buttons
# use.
#
class AnnotationModel < GLib::Object
  type_register

  # PpsAnnotationTool, in its declared order. TOOL_MAX closes the enum.
  TOOL_PENCIL = 0
  TOOL_HIGHLIGHT = 1
  TOOL_ERASER = 2
  TOOL_TEXT = 3
  TOOL_MAX = 4

  # The nicks "active-tool-str" accepts, by tool.
  TOOL_NAMES = {
    TOOL_PENCIL    => 'pencil',
    TOOL_HIGHLIGHT => 'highlighter',
    TOOL_ERASER    => 'eraser',
    TOOL_TEXT      => 'text',
  }.freeze

  DEFAULT_PEN_COLOR = '#3584e4'
  DEFAULT_HIGHLIGHT_COLOR = '#f5c211'
  DEFAULT_TEXT_COLOR = '#3584e4'
  DEFAULT_FONT = 'Adwaita Sans 12'

  install_property(
    GLib::Param::Int.new(
      'tool',
      'Tool',
      'Current tool',
      TOOL_PENCIL,
      TOOL_MAX,
      TOOL_PENCIL,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::String.new(
      'active-tool-str',
      'Tool',
      'Current tool',
      'pencil',
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Double.new(
      'eraser-radius',
      'Eraser Radius',
      'Current eraser radius',
      1.0,
      100.0,
      5.0,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Boolean.new(
      'eraser-objects',
      'Eraser Objects',
      'Whether the eraser should erase objects or ink',
      true,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Double.new(
      'highlight-radius',
      'Highlight Radius',
      'Current highlight radius',
      1.0,
      100.0,
      5.0,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Double.new(
      'pen-radius',
      'Pen Radius',
      'Current pen radius',
      1.0,
      100.0,
      1.0,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Boxed.new(
      'pen-color',
      'Pen Color',
      'Current pen color',
      Gdk::RGBA,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Boxed.new(
      'highlight-color',
      'Highlighter Color',
      'Current highlighter color',
      Gdk::RGBA,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Boxed.new(
      'text-color',
      'Text Color',
      'Current text color',
      Gdk::RGBA,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Boxed.new(
      'text-font',
      'Font for new free text annots',
      'Current font',
      Pango::FontDescription,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Double.new(
      'text-font-size',
      'Font size for new free text annots',
      'Current font size',
      1.0,
      50.0,
      8.0,
      GLib::Param::READWRITE,
    ),
  )

  def initialize
    super()
    @tool = TOOL_PENCIL
    @radius = {
      TOOL_PENCIL    => 1.0,
      TOOL_HIGHLIGHT => 5.0,
      TOOL_ERASER    => 5.0,
    }
    @color = {
      TOOL_PENCIL    => Gdk::RGBA.parse(DEFAULT_PEN_COLOR),
      TOOL_HIGHLIGHT => Gdk::RGBA.parse(DEFAULT_HIGHLIGHT_COLOR),
      TOOL_TEXT      => Gdk::RGBA.parse(DEFAULT_TEXT_COLOR),
    }
    @font_desc = Pango::FontDescription.new(DEFAULT_FONT)
    @eraser_objects = true
  end

  def tool = @tool

  # Upstream notifies unconditionally, even when the tool has not changed, and
  # notifies the string spelling of it alongside.
  def tool=(tool)
    @tool = tool
    notify('tool')
    notify('active-tool-str')
  end

  def active_tool_str = TOOL_NAMES.fetch(@tool)

  def active_tool_str=(name)
    TOOL_NAMES.key(name).then do |tool|
      if tool.nil?
        warn "AnnotationModel: unknown tool #{name.inspect}"
      else
        self.tool = tool
      end
    end
  end

  def eraser_radius = @radius.fetch(TOOL_ERASER)

  def eraser_radius=(radius)
    @radius[TOOL_ERASER] = radius
    notify('eraser-radius')
  end

  def highlight_radius = @radius.fetch(TOOL_HIGHLIGHT)

  def highlight_radius=(radius)
    @radius[TOOL_HIGHLIGHT] = radius
    notify('highlight-radius')
  end

  def pen_radius = @radius.fetch(TOOL_PENCIL)

  def pen_radius=(radius)
    @radius[TOOL_PENCIL] = radius
    notify('pen-radius')
  end

  def eraser_objects = @eraser_objects
  def eraser_objects? = @eraser_objects

  def eraser_objects=(objects)
    @eraser_objects = objects
    notify('eraser-objects')
  end

  def pen_color = @color.fetch(TOOL_PENCIL)

  def pen_color=(color)
    @color[TOOL_PENCIL] = color
    notify('pen-color')
  end

  def highlight_color = @color.fetch(TOOL_HIGHLIGHT)

  def highlight_color=(color)
    @color[TOOL_HIGHLIGHT] = color
    notify('highlight-color')
  end

  def text_color = @color.fetch(TOOL_TEXT)

  def text_color=(color)
    @color[TOOL_TEXT] = color
    notify('text-color')
  end

  def font_desc = @font_desc

  # Setting the font keeps the size that is already in effect — the font
  # chooser picks a family, the size has its own control — and does nothing
  # when the description is the one already held.
  def text_font=(font_desc)
    Pango::FontDescription.new(font_desc.to_s).tap do |desc|
      desc.size = @font_desc.size
      set_font_desc(desc)
      notify('text-font')
    end
  end

  def text_font = @font_desc

  def text_font_size = @font_desc.size.to_f / Pango::SCALE

  def text_font_size=(size)
    Pango::FontDescription.new(@font_desc.to_s).tap do |desc|
      desc.size = (size * Pango::SCALE).to_i
      set_font_desc(desc)
      notify('text-font-size')
    end
  end

  # pps_annotation_model_set_font_desc: a no-op when the description is equal
  # to the one held, and a "notify::text-font" otherwise.
  def set_font_desc(font_desc)
    @font_desc.to_s.eql?(font_desc.to_s).then do |same|
      unless same
        @font_desc = Pango::FontDescription.new(font_desc.to_s)
        notify('text-font')
      end
    end
  end
end
