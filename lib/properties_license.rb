# frozen_string_literal: true

require 'adwaita'
require 'cgi'
require 'uri'

# PropertiesLicense shows a document's usage terms: the license text itself,
# a link to its machine-readable text, and a link to further information.
#
# Ported from upstream's shell/src/properties_license.rs and its template
# shell/resources/pps-properties-license.blp. Upstream's three rows each come
# in a box that is hidden whenever the document's license has nothing for
# that row (no text, no URI, no web statement); #document_license= does the
# same here, toggling each box's visibility rather than hiding the row
# unconditionally per rule 11 of this port's style guide — the box's content
# itself (the heading label) is static and always shown, only whether the
# whole box appears changes with the data.
#
class PropertiesLicense < Adwaita::Bin
  type_register

  def build
    tap { |bin| bin.child = clamp }
  end

  # Sets the three rows from a license. `license` answers #text, #uri and
  # #web_statement, each either a String or nil — the same shape upstream's
  # DocumentLicense exposes through its own typed getters.
  def document_license=(license)
    license.text.then do |text|
      license_box.visible = !text.nil?
      license_label.text = text.to_s
    end

    license.uri.then do |uri|
      uri_box.visible = !uri.nil?
      set_uri_label(uri_label, uri) unless uri.nil?
    end

    license.web_statement.then do |web_statement|
      web_statement_box.visible = !web_statement.nil?
      set_uri_label(web_statement_label, web_statement) unless web_statement.nil?
    end
  end

  def clamp = @clamp ||= Adwaita::Clamp.new.tap { |c| c.child = content_box }

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.margin_start = 12
      box.margin_end = 12
      box.margin_top = 12
      box.margin_bottom = 12
      box.append(license_box)
      box.append(uri_box)
      box.append(web_statement_box)
    end
  end

  def license_box
    @license_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.append(heading('Usage Terms'))
      box.append(license_scroller)
    end
  end

  def license_scroller
    @license_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
      scroller.hscrollbar_policy = :never
      scroller.min_content_height = 150
      scroller.has_frame = true
      scroller.child = license_label
    end
  end

  def license_label
    @license_label ||= Gtk::Label.new.tap do |label|
      label.wrap = true
      label.wrap_mode = :word_char
      label.selectable = true
      label.margin_start = 12
      label.xalign = 0
      label.add_css_class('body')
      label.add_css_class('link')
    end
  end

  def uri_box
    @uri_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.append(heading('Text License'))
      box.append(uri_label)
    end
  end

  def uri_label = @uri_label ||= link_label

  def web_statement_box
    @web_statement_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.append(heading('Further Information'))
      box.append(web_statement_label)
    end
  end

  def web_statement_label = @web_statement_label ||= link_label

  private

    def heading(text)
      Gtk::Label.new(text).tap do |label|
        label.xalign = 0
        label.add_css_class('heading')
      end
    end

    def link_label
      Gtk::Label.new.tap do |label|
        label.margin_start = 12
        label.selectable = true
        label.ellipsize = :end
        label.width_chars = 25
        label.xalign = 0
        label.add_css_class('body')
        label.add_css_class('link')
      end
    end

    # Markup a known-scheme URI as a clickable link; otherwise show it as
    # plain text. Matches upstream's set_uri_to_label, which only markup-links
    # a string glib::uri_parse_scheme recognizes as having a scheme.
    def set_uri_label(label, uri)
      if uri?(uri)
        escaped = CGI.escape_html(uri)
        label.set_markup("<a href=\"#{escaped}\">#{escaped}</a>")
      else
        label.text = uri
      end
    end

    def uri?(uri)
      !URI.parse(uri).scheme.nil?
    rescue URI::InvalidURIError
      false
    end
end
