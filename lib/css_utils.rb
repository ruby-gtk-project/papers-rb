# frozen_string_literal: true

require 'adwaita'

# CssUtils turns a Pango font description into GTK CSS, and filters a string
# down to the characters a CSS class name may contain.
#
# Ported from upstream's libview/pps-css-utils.c. The first half of that file
# is copied from libdazzle (dzl_pango_font_description_to_css) and is what
# lets the annotation widgets render text in the font the annotation asks for:
# the font description becomes a declaration block, which goes into a
# provider. The second half is used wherever a document-supplied name — a
# layer's title, say — becomes a CSS class.
#
module CssUtils
  FONT_FAMILY = 'font-family'
  FONT_STYLE = 'font-style'
  FONT_VARIANT = 'font-variant'
  FONT_STRETCH = 'font-stretch'
  FONT_WEIGHT = 'font-weight'

  STYLES = {
    Pango::Style::NORMAL  => 'normal',
    Pango::Style::OBLIQUE => 'oblique',
    Pango::Style::ITALIC  => 'italic',
  }.freeze

  VARIANTS = {
    Pango::Variant::NORMAL     => 'normal',
    Pango::Variant::SMALL_CAPS => 'small-caps',
  }.freeze

  # The two weights libdazzle spells with a keyword. SEMILIGHT (350) is not a
  # valid CSS weight, so it rounds up to normal with them.
  NAMED_WEIGHTS = {
    Pango::Weight::SEMILIGHT.to_i => 'normal',
    Pango::Weight::NORMAL.to_i    => 'normal',
    Pango::Weight::BOLD.to_i      => 'bold',
  }.freeze

  STRETCHES = {
    Pango::Stretch::ULTRA_CONDENSED => 'ultra-condensed',
    Pango::Stretch::EXTRA_CONDENSED => 'extra-condensed',
    Pango::Stretch::CONDENSED       => 'condensed',
    Pango::Stretch::SEMI_CONDENSED  => 'semi-condensed',
    Pango::Stretch::NORMAL          => 'normal',
    Pango::Stretch::SEMI_EXPANDED   => 'semi-expanded',
    Pango::Stretch::EXPANDED        => 'expanded',
    Pango::Stretch::EXTRA_EXPANDED  => 'extra-expanded',
    Pango::Stretch::ULTRA_EXPANDED  => 'ultra-expanded',
  }.freeze

  # Only the fields the description actually sets are emitted, so a
  # declaration block never overrides a property the caller left to the theme.
  # Size is deliberately absent: libdazzle's function does not emit it.
  def self.font_description_to_css(font_desc)
    font_desc.set_fields.then do |mask|
      [
        family_declaration(font_desc, mask),
        keyword_declaration(
          FONT_STYLE,
          STYLES,
          font_desc.style,
          mask.style?,
        ),
        keyword_declaration(
          FONT_VARIANT,
          VARIANTS,
          font_desc.variant,
          mask.variant?,
        ),
        weight_declaration(font_desc, mask),
        keyword_declaration(
          FONT_STRETCH,
          STRETCHES,
          font_desc.stretch,
          mask.stretch?,
        ),
      ].compact.join
    end
  end

  def self.family_declaration(font_desc, mask)
    if mask.family?
      %(#{FONT_FAMILY}:"#{font_desc.family}";)
    end
  end

  def self.keyword_declaration(property, keywords, value, set)
    if set
      keywords[value].then do |keyword|
        unless keyword.nil?
          "#{property}:#{keyword};"
        end
      end
    end
  end

  # Numeric font-weight did not work as expected when libdazzle was written,
  # so the common weights use their keyword and everything else is rounded to
  # the nearest hundred and emitted as a number.
  def self.weight_declaration(font_desc, mask)
    if mask.weight?
      font_desc.weight.to_i.then do |weight|
        NAMED_WEIGHTS[weight].then do |keyword|
          if keyword.nil?
            "#{FONT_WEIGHT}:#{(weight / 100.0).round * 100};"
          else
            "#{FONT_WEIGHT}:#{keyword};"
          end
        end
      end
    end
  end

  # A CSS class name may hold a-z, A-Z, 0-9, "-" and "_", plus any character
  # from U+00A0 up. Everything else is dropped. A nil name becomes "(null)",
  # the string upstream's g_strdup("(null)") produces.
  def self.filter_class_chars(str)
    if str.nil?
      '(null)'
    else
      str.each_char.select { |char| class_char?(char) }.join
    end
  end

  def self.class_char?(char)
    char.ord.then do |ord|
      if ord <= 0x7F
        char.match?(/[a-zA-Z0-9_-]/)
      else
        ord >= 0x00A0
      end
    end
  end
end
