# frozen_string_literal: true

require 'adwaita'

# LoaderView is the page the window shows while a document is being loaded.
#
# Ported from upstream's shell/src/loader_view.rs and
# shell/resources/pps-loader-view.blp: a status page naming the document being
# opened, a spinner or a progress bar depending on whether the loader can
# report progress, and a Cancel button.
#
# A negative fraction means "no progress information", and switches to the
# spinner; any other fraction drives the bar. That is the whole of upstream's
# set_fraction.
#
class LoaderView < Adwaita::Bin
  type_register

  SPINNER_PAGE = 'spinner'
  BAR_PAGE = 'bar'

  define_signal(
    'cancel',
    GLib::Signal::RUN_LAST,
    nil,
    nil,
  )

  install_property(
    GLib::Param::Double.new(
      'fraction',
      'Fraction',
      'How much of the document has loaded, or a negative value for unknown',
      -Float::MAX,
      Float::MAX,
      0.0,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::String.new(
      'uri',
      'URI',
      'The URI being loaded',
      '',
      GLib::Param::READWRITE,
    ),
  )

  attr_reader :fraction, :uri

  def initialize
    super()
    @fraction = 0.0
    @uri = ''
  end

  def signal_do_cancel = nil

  def build
    tap do |view|
      view.child = toolbar_view

      toolbar_view.tap do |bars|
        bars.add_top_bar(header_bar)
        bars.content = status_page

        header_bar.title_widget = window_title

        status_page.child = content_box

        content_box.tap do |box|
          box.append(clamp)
          box.append(cancel_button)

          clamp.child = stack

          stack.tap do |pages|
            pages.add_named(spinner, SPINNER_PAGE)
            pages.add_named(progress_bar, BAR_PAGE)
          end

          cancel_button.signal_connect('clicked') { signal_emit('cancel') }
        end
      end
    end
  end

  def fraction=(fraction)
    fraction.negative?.then do |unknown|
      if unknown
        stack.visible_child_name = SPINNER_PAGE
      else
        progress_bar.fraction = fraction
        stack.visible_child_name = BAR_PAGE
      end
    end

    @fraction = fraction
    notify('fraction')
  end

  # The status page's description is bound to the URI in upstream's template.
  def uri=(uri)
    @uri = uri
    status_page.description = uri
    notify('uri')
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new
  def window_title = @window_title ||= Adwaita::WindowTitle.new('Document Viewer', '')

  def status_page
    @status_page ||= Adwaita::StatusPage.new.tap do |page|
      page.title = 'Loading Document'
    end
  end

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 24)
  end

  def clamp = @clamp ||= Adwaita::Clamp.new

  def stack
    @stack ||= Gtk::Stack.new
  end

  def spinner
    @spinner ||= Adwaita::Spinner.new.tap do |widget|
      widget.width_request = 64
      widget.height_request = 64
    end
  end

  def progress_bar
    @progress_bar ||= Gtk::ProgressBar.new.tap do |bar|
      bar.show_text = true
      bar.width_request = 250
      bar.halign = :center
    end
  end

  def cancel_button
    @cancel_button ||= Gtk::Button.new.tap do |button|
      button.halign = :center
      button.use_underline = true
      button.label = 'C_ancel'
      button.add_css_class('pill')
    end
  end
end
