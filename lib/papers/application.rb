# frozen_string_literal: true

require "adwaita"

require_relative "../settings"
require_relative "../style"
require_relative "../shortcuts_dialog"
require_relative "../annotation_window"
require_relative "../window"

module Papers
  # The port's application object.
  #
  # Ported from upstream's shell/src/application.rs: the application id and
  # flags, the application name and icon set at startup, the stylesheet, the
  # app-level actions (about, help, quit, new, shortcuts) and the accelerators
  # that file binds — including the win.* ones, which an application binds on
  # behalf of its windows.
  #
  # Upstream's windows come from PpsWindow and its ViewStack; the content here
  # is the application's own chrome: the main menu from
  # shell/resources/pps-window.blp, whose three items are all app actions, and
  # a status page naming the application.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = "org.rubygtkproject.Papers"
    APP_NAME = "Document Viewer"
    HELP_URI = "help:papers"

    # Upstream's setup_actions accelerators, app.* and win.* alike.
    #
    # Upstream's "win.presentation" is left out: it targets
    # PpsViewPresentation, which does not exist in this port yet (see
    # view.rb in the inventory), and binding it to window.rb's "open",
    # "close", "fullscreen" and "night-mode" GActions is the whole point —
    # a fifth accelerator aimed at nothing would silently no-op exactly like
    # the ones this round fixes.
    ACCELS = {
      "app.help"       => ["F1"],
      "app.new"        => ["<Ctrl>N"],
      "app.new-note"   => ["<Ctrl><Shift>N"],
      "app.quit"       => ["<Ctrl>Q"],
      "win.open"       => ["<Ctrl>O"],
      "win.close"      => ["<Ctrl>W"],
      "win.fullscreen" => ["F11"],
      "win.night-mode" => ["<Ctrl>I"],
    }.freeze

    COPYRIGHT = "© 1996–2025 The Papers authors"

    DEVELOPERS = [
      "Martin Kretzschmar <m_kretzschmar@gmx.net>",
      "Jonathan Blandford <jrb@gnome.org>",
      "Marco Pesenti Gritti <marco@gnome.org>",
      "Nickolay V. Shmyrev <nshmyrev@yandex.ru>",
      "Bryan Clark <clarkbw@gnome.org>",
      "Carlos Garcia Campos <carlosgc@gnome.org>",
      "Wouter Bolsterlee <wbolster@gnome.org>",
      "Christian Persch <chpe@src.gnome.org>",
      "Germán Poo-Caamaño <gpoo@gnome.org>",
      "Qiu Wenbo <qiuwenbo@gnome.org>",
      "Pablo Correa Gómez <ablocorrea@hotmail.com>",
      "Markus Göllnitz https://bewares.it/",
    ].freeze

    DOCUMENTERS = [
      "Nickolay V. Shmyrev <nshmyrev@yandex.ru>",
      "Phil Bull <philbull@gmail.com>",
      "Tiffany Antpolski <tiffany.antopolski@gmail.com>",
    ].freeze

    def initialize(settings: nil, present: true)
      @settings = settings || Settings.new
      @present = present
    end

    attr_reader :settings

    def build
      app.tap do
        app.signal_connect("startup") do
          GLib.application_name = APP_NAME
          Gtk::Window.set_default_icon_name(APP_ID)
          Style.install_shell
          setup_actions
        end

        app.signal_connect("activate") do
          unless @window_built
            @window_built = true
            window.build.tap do |win|
              win.start_menu_button.menu_model = app_menu
              win.start_header_bar.pack_end(new_note_button)
            end
          end

          if @present
            window.present
          end
        end
      end
    end

    def run(argv = []) = app.run(argv)

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the window is Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :non_unique)

    # The real PpsWindow (see window.rb) rather than a bare ApplicationWindow:
    # the sidebar/document layout, the win.* actions and the open/error/
    # password/loader pages all live there now.
    def window = @window ||= Window.new(application: app, settings: settings)

    # The main menu from shell/resources/pps-window.blp. Every item in it is an
    # application action, so the menu belongs to the application.
    def app_menu
      @app_menu ||= Gio::Menu.new.tap do |menu|
        menu.append("_Keyboard Shortcuts", "app.shortcuts")
        menu.append("_Help", "app.help")
        menu.append("_About Document Viewer", "app.about")
      end
    end

    # Opens a standalone AnnotationWindow (see annotation_window.rb), the
    # one spot in this port's current surface that calls into libspelling.
    def new_note_button
      @new_note_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "list-add-symbolic"
        button.tooltip_text = "New Note"
        button.action_name = "app.new-note"
      end
    end

    def shortcuts_dialog = @shortcuts_dialog ||= ShortcutsDialog.new.build

    def about_dialog
      @about_dialog ||= Adwaita::AboutDialog.new.tap do |about|
        about.application_name = APP_NAME
        about.application_icon = APP_ID
        about.copyright = COPYRIGHT
        about.license_type = Gtk::License::GPL_2_0
        about.developers = DEVELOPERS
        about.documenters = DOCUMENTERS
        about.website = "https://apps.gnome.org/Papers/"
        about.version = Papers::Rb::Version::VERSION
      end
    end

    private

      def setup_actions
        {
          "about"     => -> { about_dialog.present(app.active_window) },
          "help"      => -> { show_help },
          "shortcuts" => -> { shortcuts_dialog.present(app.active_window) },
          "new"       => -> { app.activate },
          "new-note"  => -> { open_annotation_window },
          "quit"      => -> { quit },
        }.each { |name, handler| app.add_action(action(name, handler)) }

        ACCELS.each { |target, accels| app.set_accels_for_action(target, accels) }
      end

      def action(name, handler)
        Gio::SimpleAction.new(name).tap do |simple|
          simple.signal_connect("activate") { handler.call }
        end
      end

      # Each press opens a fresh note window, matching upstream's
      # add-annotation flow (a new PpsAnnotationWindow per annotation),
      # rather than one window reused across presses.
      def open_annotation_window
        AnnotationWindow.new(
          title: "Note",
          enable_spellchecking: settings.default["enable-spellchecking"],
        ).build.tap do |note|
          note.transient_for = app.active_window
          note.present
        end
      end

      def show_help
        Gio::AppInfo.launch_default_for_uri(HELP_URI, nil)
      rescue Gio::Error, GLib::Error => e
        warn "Failed to launch help: #{e.message}"
      end

      # Closing the application means closing its windows: a window is the only
      # thing holding the application up, and a background job that has taken a
      # hold of its own must be allowed to finish.
      def quit
        app.windows.each(&:close)
      end
  end
end
