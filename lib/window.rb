# frozen_string_literal: true

require 'adwaita'
require_relative 'settings'
require_relative 'loader_view'
require_relative 'password_view'

# Window is the Ruby port's PpsWindow, the application's document window.
#
# Ported from upstream's shell/src/window.rs and shell/resources/pps-window.blp:
# an Adw.ToastOverlay over a Gtk::Stack whose pages are "start" (nothing open
# yet), "error" (the last open failed), "password" (the open document is
# locked) and "loader" (a document is being read). Upstream's stack has two
# further pages, "document" and "presentation", which need PpsDocumentView
# and PpsViewPresentation — neither exists in this port yet (see
# document_view.rb and view.rb in the inventory) — so #open_file's only real
# outcome today is one of the first four pages. That is not a stand-in: it is
# upstream's own factory-miss path (pps_document_factory_get_document finding
# no backend for a mime type), which is what every file hits while no
# PpsDocument backend is registered, exactly as it would upstream.
#
# The win.* GActions mirror upstream's setup_actions:
#   - "open"    asks GTK for a file (Gtk::FileDialog) and runs it through
#               #open_file, matching cmd_file_open.
#   - "close"   closes the window.
#   - "fullscreen" and "night-mode" are upstream's two stateful boolean
#               actions; night-mode also drives Adwaita::StyleManager and is
#               persisted to Settings' root schema, as window_fullscreened /
#               set_night_mode do.
#   - "presentation" has no PpsViewPresentation to switch to, so, per the
#               instruction to wire a dead accelerator to a real action or
#               drop it, it is dropped here rather than left as a no-op.
#
class Window < Adwaita::ApplicationWindow
  MODE_START = 'start'
  MODE_ERROR = 'error'
  MODE_PASSWORD = 'password'
  MODE_LOADER = 'loader'

  attr_reader :mode

  def initialize(application:, settings:)
    super(application)
    @settings = settings
    @mode = MODE_START
  end

  def build
    tap do |win|
      win.title = 'Document Viewer'
      win.width_request = 360
      win.height_request = 360
      win.content = toast_overlay
      win.add_controller(drop_target)

      win.add_action(open_action)
      win.add_action(close_action)
      win.add_action(fullscreen_action)
      win.add_action(night_mode_action)

      win.signal_connect('notify::fullscreened') { sync_fullscreen_action }
      win.signal_connect('close-request') { handle_close_request }

      toast_overlay.tap do |overlay|
        overlay.child = stack
      end

      stack.tap do |s|
        s.add_named(start_toolbar_view, MODE_START)
        s.add_named(error_toolbar_view, MODE_ERROR)
        s.add_named(password_view.build, MODE_PASSWORD)
        s.add_named(loader_view.build, MODE_LOADER)
        s.visible_child_name = MODE_START
      end

      start_toolbar_view.tap do |view|
        view.add_top_bar(start_header_bar)
        view.content = start_status_page
      end

      error_toolbar_view.tap do |view|
        view.add_top_bar(Adwaita::HeaderBar.new)
        view.content = error_status_page
      end

      password_view.signal_connect('cancelled') { set_mode(MODE_START) }
      loader_view.signal_connect('cancel') { set_mode(MODE_START) }

      drop_target.signal_connect('drop') { |_target, value, _x, _y| handle_drop(value) }

      @settings.default.apply_to(win)
      apply_night_mode(@settings.night_mode?)
    end
  end

  # Upstream's cmd_file_open result, reached either from the "open" action or
  # from a drop: shows the loader page, asks GIO for the file's content type,
  # and hands the real result to #show_error, since no backend in this port
  # recognises any content type yet.
  def open_file(file)
    loader_view.uri = file.uri
    set_mode(MODE_LOADER)

    file.query_info_async(
      'standard::content-type',
      Gio::FileQueryInfoFlags::NONE,
      GLib::PRIORITY_DEFAULT,
      nil,
    ) do |source, result|
      begin
        info = source.query_info_finish(result)
        show_error("No document backend is registered for “#{info.content_type}” files.")
      rescue GLib::Error => e
        show_error(e.message)
      end
    end
  end

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
  def stack = @stack ||= Gtk::Stack.new
  def loader_view = @loader_view ||= LoaderView.new
  def password_view = @password_view ||= PasswordView.new

  def start_toolbar_view = @start_toolbar_view ||= Adwaita::ToolbarView.new
  def start_header_bar
    @start_header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.pack_end(start_menu_button)
    end
  end

  def start_menu_button
    @start_menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'open-menu-symbolic'
      button.tooltip_text = 'Main Menu'
      button.primary = true
    end
  end

  def start_status_page
    @start_status_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'x-office-document-symbolic'
      page.title = 'Open a Document'
      page.description = 'Drag and drop documents here'
      page.child = open_button
    end
  end

  def open_button
    @open_button ||= Gtk::Button.new.tap do |button|
      button.halign = :center
      button.use_underline = true
      button.label = '_Open…'
      button.action_name = 'win.open'
      button.tooltip_text = 'Open a Document'
      button.add_css_class('suggested-action')
      button.add_css_class('pill')
    end
  end

  def error_toolbar_view = @error_toolbar_view ||= Adwaita::ToolbarView.new

  def error_status_page
    @error_status_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'dialog-error-symbolic'
      page.title = 'Unable to Open Document'
      page.child = retry_button
    end
  end

  def retry_button
    @retry_button ||= Gtk::Button.new.tap do |button|
      button.halign = :center
      button.use_underline = true
      button.label = '_Open Other File…'
      button.action_name = 'win.open'
      button.add_css_class('suggested-action')
      button.add_css_class('pill')
    end
  end

  def drop_target = @drop_target ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy)

  def open_action
    @open_action ||= Gio::SimpleAction.new('open').tap do |action|
      action.signal_connect('activate') { prompt_open_file }
    end
  end

  def close_action
    @close_action ||= Gio::SimpleAction.new('close').tap do |action|
      action.signal_connect('activate') { close }
    end
  end

  # Stateful boolean action, same shape as upstream's gio::ActionEntryBuilder
  # for "fullscreen": the state the accelerator (F11) flips drives the real
  # window-manager fullscreen call.
  def fullscreen_action
    @fullscreen_action ||= Gio::SimpleAction.new('fullscreen', nil, GLib::Variant.new(false)).tap do |action|
      action.signal_connect('activate') do
        (!action.state).tap do |enabled|
          action.set_state(GLib::Variant.new(enabled))

          if enabled
            fullscreen
          else
            unfullscreen
          end
        end
      end
    end
  end

  # Stateful boolean action for upstream's "night-mode": applies the color
  # scheme through Adwaita::StyleManager (the house way to do it — see
  # ruby-gtk skill — rather than the unsupported GtkSettings property) and
  # persists the choice to Settings' root schema, mirroring set_night_mode.
  def night_mode_action
    @night_mode_action ||= Gio::SimpleAction.new(
      'night-mode',
      nil,
      GLib::Variant.new(@settings.night_mode?),
    ).tap do |action|
      action.signal_connect('activate') do
        (!action.state).tap do |enabled|
          action.set_state(GLib::Variant.new(enabled))
          apply_night_mode(enabled)
        end
      end
    end
  end

  private

    def set_mode(mode)
      @mode = mode
      stack.visible_child_name = mode
    end

    def show_error(message)
      error_status_page.description = message
      set_mode(MODE_ERROR)
    end

    def prompt_open_file
      Gtk::FileDialog.new.tap do |dialog|
        dialog.modal = true
        dialog.open(self) do |_source, result|
          begin
            open_file(dialog.open_finish(result))
          rescue GLib::Error
            nil
          end
        end
      end
    end

    def handle_drop(value)
      value.files.first.then { |file| open_file(file) unless file.nil? }
      true
    end

    def handle_close_request
      @settings.default.remember(self)
      false
    end

    # Keeps the stateful "fullscreen" action in sync when the window manager
    # (rather than the accelerator) changes fullscreened — upstream's
    # window_fullscreened template callback.
    def sync_fullscreen_action
      unless fullscreened?
        fullscreen_action.set_state(GLib::Variant.new(false))
      end
    end

    def apply_night_mode(enabled)
      Adwaita::StyleManager.default.color_scheme =
        enabled ? Adwaita::ColorScheme::FORCE_DARK : Adwaita::ColorScheme::DEFAULT
      @settings.night_mode = enabled
    end
end
