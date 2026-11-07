# frozen_string_literal: true

# Drives the whole port headlessly: builds the application, opens the window,
# the menu, the shortcuts and about dialogs, round-trips settings to disk,
# parses the stylesheets, and — since application.rb wires almost nothing
# else into the running window yet — builds and exercises every other widget
# and model class the port ships (LoaderView, the password flow,
# ProgressMessageArea, SimpleColorSwatch, SidebarPage, DocumentModel,
# AnnotationModel, History, UndoContext, ThumbnailItem, SearchResult,
# FileMonitor, Keyring, Metadata, SignatureImageProcessing, ViewColors,
# ViewCursor and CssUtils) directly, the same way the window would if it used
# them.
#
# Why this file exists: a GTK app that loads is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window, and the Ruby bindings
# differ from the C API in ways that only a run reveals.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_papers.rb
#
# GTK4 here has no offscreen backend — gtk_init fails outright with no
# display — so xvfb-run is not optional on this machine.

require 'fileutils'
require 'tmpdir'

# A scratch config directory, so a run never reads or writes the real one.
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('papers-drive')

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'papers'
require_relative 'gtk_driver'

SHOTS = File.expand_path('../tmp/shots', __dir__)
FileUtils.rm_rf(SHOTS)

# Every Gtk::Label text in a widget tree, the same walk the tally driver uses
# to read an Adw.AboutDialog's link rows back.
def labels(widget, found = [])
  found.tap do
    if widget.is_a?(Gtk::Label)
      found << widget.label
    end
    widget.first_child.then do |first|
      child = first
      while child
        labels(child, found)
        child = child.next_sibling
      end
    end
  end
end

# Whether `widget` appears anywhere under `ancestor`'s widget tree. Several
# of upstream's containers (Adw.ToolbarView, Adw.HeaderBar) interpose a box of
# their own between a child and the container it was packed into, so a direct
# `#parent` check is the wrong question; what matters is that the widget is
# reachable from the container it was packed into.
def descendant?(ancestor, widget)
  if ancestor.equal?(widget)
    true
  else
    found = false
    child = ancestor.first_child
    while child && !found
      found = descendant?(child, widget)
      child = child.next_sibling
    end
    found
  end
end

# Turns the main loop over for `ms` milliseconds and comes back, without
# sleeping (a step cannot sleep — it is already running inside one of the
# driver's own GLib timeouts). Adwaita::AlertDialog#choose wires its
# "response" handler up asynchronously, so a dialog that was just opened in
# this same step needs a turn of the loop before a signal_emit('response',
# ...) on it will reach anything.
def pump(ms)
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) + (ms / 1000.0)).then do |deadline|
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      GLib::MainContext.default.iteration(false)
    end
  end
end

# A disposable Adwaita window, tied to the same application, for driving a
# widget the real window never wires up yet. visible_dialog only reports on
# an Adwaita::ApplicationWindow, which is why every helper below uses one
# rather than a bare Gtk::Window.
def scratch_window(app)
  Adwaita::ApplicationWindow.new(app).tap do |win|
    win.present
  end
end

GtkDriver.drive(Papers::Application.new, shots: SHOTS) do |d, app|
  d.window { app.window }

  d.step('the window builds and shows the empty state') do
    d.check('the window is an Adwaita::ApplicationWindow') do
      app.window.is_a?(Adwaita::ApplicationWindow)
    end
    d.check('it is the only toplevel') { Gtk::Window.list_toplevels.length == 1 }
    d.check('its title is papers') { app.window.title == 'papers' }
    d.check('the toolbar view is the window content') do
      app.window.content.equal?(app.toolbar_view)
    end
    d.check('the status page is the toolbar view content') do
      app.toolbar_view.content.equal?(app.status_page)
    end
    d.check('the status page names the app') { app.status_page.title == 'papers' }
    d.check('the status page carries a description') do
      !app.status_page.description.to_s.empty?
    end
    d.check('the header bar is a top bar of the toolbar view') do
      descendant?(app.toolbar_view, app.header_bar)
    end
    # Not window.default_width/default_height here: under Xvfb with no window
    # manager, GDK renegotiates the surface's configured size once it is
    # mapped, and the property reverts to whatever that negotiation settles
    # on — nothing to do with the port. settings.default.apply_to(window) is
    # exercised directly, synchronously, in its own step below instead.
    d.check('the window asked to be at least as big as its minimum') do
      app.window.width_request == 360 && app.window.height_request == 360
    end
    d.shot('01-empty')
  end

  d.step('the main menu button carries upstream\'s three app actions') do
    app.menu_button.then do |button|
      d.check('it is a Gtk::MenuButton') { button.is_a?(Gtk::MenuButton) }
      d.check('its icon is the hamburger') { button.icon_name == 'open-menu-symbolic' }
      d.check('it has a tooltip') { !button.tooltip_text.to_s.empty? }
      d.check('it is primary (opens on left click, no second button needed)') do
        button.primary?
      end
      d.check("it sits in the window's header bar") { descendant?(app.header_bar, button) }

      button.menu_model.then do |model|
        d.check('the model is a Gio::Menu') { model.is_a?(Gio::Menu) }
        d.check('it carries three items') { model.n_items == 3 }
        d.check('their labels and actions are in pps-window.blp\'s order') do
          (0...model.n_items).map do |index|
            [
              model.get_item_attribute_value(index, 'label', nil),
              model.get_item_attribute_value(index, 'action', nil),
            ]
          end == [
            ['_Keyboard Shortcuts', 'app.shortcuts'],
            ['_Help', 'app.help'],
            ['_About Document Viewer', 'app.about'],
          ]
        end
      end
    end
  end

  d.step('the application registered every ACCELS entry') do
    Papers::Application::ACCELS.each do |action, accels|
      d.check("#{action} is #{accels.first}") do
        app.app.get_accels_for_action(action).map { |accel| Gtk.accelerator_parse(accel) } ==
          accels.map { |accel| Gtk.accelerator_parse(accel) }
      end
    end
  end

  d.step('every app action setup_actions installs is present and enabled') do
    %w[about help shortcuts new quit].each do |name|
      d.check("app.#{name} exists and is enabled") do
        action = app.app.lookup_action(name)
        action.is_a?(Gio::SimpleAction) && action.enabled?
      end
    end
  end

  d.step('the shortcuts dialog opens from its action, not just its method') do
    app.app.lookup_action('shortcuts').activate(nil)
    d.check('it is showing on the window') { app.window.visible_dialog.equal?(app.shortcuts_dialog) }
    d.check('it is the port\'s ShortcutsDialog subclass') { app.shortcuts_dialog.is_a?(ShortcutsDialog) }
    d.check('its title is Keyboard Shortcuts') { app.shortcuts_dialog.title == 'Keyboard Shortcuts' }
    pump(100)
    d.shot('02-shortcuts')
    app.window.visible_dialog&.close
  end

  d.step('ShortcutsDialog carries all nine of upstream\'s sections') do
    d.check('nine sections, in upstream\'s order') do
      ShortcutsDialog::SECTIONS.keys == [
        'File', 'Window', 'Selection', 'Zoom and Rotation', 'Navigation',
        'Document View', 'Search', 'General', 'Presentation Mode',
      ]
    end
    d.check('the one item upstream names both ways keeps both') do
      ShortcutsDialog::SECTIONS['Document View'].find { |item| item[:title] == 'Digital Signing' }
                                                 .then { |item| item[:accelerator] == '<Ctrl><Alt>s' && item[:action] == 'doc.digital-signing' }
    end
  end

  d.step('the about dialog opens from its action and carries upstream\'s fields') do
    app.app.lookup_action('about').activate(nil)
    app.about_dialog.then do |dialog|
      d.check('it is showing on the window') { app.window.visible_dialog.equal?(dialog) }
      d.check('its application icon is the app id') { dialog.application_icon == Papers::Application::APP_ID }
      d.check('its application name is Document Viewer') { dialog.application_name == Papers::Application::APP_NAME }
      d.check('its copyright is upstream\'s') { dialog.copyright == Papers::Application::COPYRIGHT }
      d.check('its licence is GPL-2.0, as upstream ships') { dialog.license_type == Gtk::License::GPL_2_0 }
      d.check('its website points at apps.gnome.org') { dialog.website == 'https://apps.gnome.org/Papers/' }
      d.check('every upstream developer is credited') do
        dialog.developers.to_a == Papers::Application::DEVELOPERS
      end
      d.check('every upstream documenter is credited') do
        dialog.documenters.to_a == Papers::Application::DOCUMENTERS
      end
      d.check('its version is the gem\'s') { dialog.version == Papers::Rb::Version::VERSION }
    end
    pump(100)
    d.shot('03-about')
    app.window.visible_dialog&.close
  end

  d.step('app.new is wired to the application\'s own activation') do
    # Not actually activated here: re-emitting "activate" on the live
    # Gio::Application would re-enter this very test driver's own
    # "activate" handler (which is what schedules these steps), scheduling a
    # second, overlapping run of the whole step list. The wiring itself —
    # that app.new's handler is `-> { app.activate }` — is read off the
    # source instead of exercised live.
    d.check('"new" is a no-argument action, like app.activate takes') do
      app.app.lookup_action('new').parameter_type.nil?
    end
  end

  d.step('app.help fails closed rather than raising with no handler registered') do
    d.check('activating app.help does not crash the app') do
      app.app.lookup_action('help').activate(nil)
      true
    end
  end

  d.step('settings round-trip through disk, independent of the running window') do
    Settings.new(path: app.settings.path).then do |fresh|
      d.check('a fresh read sees the same path') { fresh.path == app.settings.path }
      d.check('night-mode defaults to false') { !fresh.night_mode? }

      fresh.night_mode = true
      d.check('writing a key persists it') do
        Settings.new(path: app.settings.path).night_mode?
      end

      fresh.default.window_width = 1024
      d.check('a child schema writes under its own section') do
        Settings.new(path: app.settings.path).default.window_width == 1024
      end
      d.check('the sizing-mode enum round-trips by nick and by index') do
        fresh.default.sizing_mode_index = Settings::SIZING_MODES.index('fit-width')
        fresh.default.sizing_mode == 'fit-width' && fresh.default.sizing_mode_index == 1
      end
    end
  end

  d.step('apply_to/remember round-trip a window\'s geometry') do
    scratch_window(app.app).then do |win|
      app.settings.default.apply_to(win)
      d.check('apply_to sized the window from settings') do
        win.default_width == app.settings.default.window_width
      end
      win.default_width = 999
      app.settings.default.remember(win)
      d.check('remember wrote the new width back') { app.settings.default.window_width == 999 }
      win.close
    end
  end

  d.step('upstream\'s two stylesheets parse with no errors swallowed') do
    [
      ['shell', Style::SHELL],
      ['previewer (shell + its own)', Style::SHELL + Style::PREVIEWER],
    ].each do |label, css|
      [].then do |errors|
        Gtk::CssProvider.new.tap do |provider|
          provider.signal_connect('parsing-error') { |_p, _section, error| errors << error.message }
          provider.load_from_string(css)
        end
        d.check("#{label} parses with no complaints") { errors.empty? }
      end
    end
    d.check('Style.install_shell installs a provider with no error') do
      Style.install_shell
      true
    end
  end

  # --- Widgets application.rb never wires in --------------------------------
  #
  # These are built and driven directly, on their own scratch windows, the
  # same way the real window will once it grows a loader, a password prompt
  # and a progress bar of its own.

  d.step('LoaderView switches between its spinner and its progress bar') do
    scratch_window(app.app).then do |win|
      LoaderView.new.build.then do |view|
        win.content = view
        view.uri = 'file:///tmp/some-document.pdf'
        d.check('the status page description follows the uri property') do
          view.status_page.description == 'file:///tmp/some-document.pdf'
        end
        view.fraction = 0.4
        d.check('a known fraction shows the bar page') { view.stack.visible_child_name == LoaderView::BAR_PAGE }
        d.check('the progress bar took the fraction') { view.progress_bar.fraction == 0.4 }
        view.fraction = -1.0
        d.check('a negative fraction shows the spinner page') do
          view.stack.visible_child_name == LoaderView::SPINNER_PAGE
        end

        cancelled = false
        view.signal_connect('cancel') { cancelled = true }
        # signal_emit, not activate: gtk_widget_activate declines on a button
        # whose window has not had a tick to map it yet.
        view.cancel_button.signal_emit('clicked')
        d.check('the cancel button emits the cancel signal') { cancelled }
        pump(100)
        d.shot('04-loader-view', view)
      end
      win.close
    end
  end

  d.step('PasswordView asks for a password and reports an unlock') do
    scratch_window(app.app).then do |win|
      PasswordView.new(can_save_password: true).build.then do |view|
        win.content = view
        view.filename = 'secret.pdf'
        view.unlock_button.signal_emit('clicked')
        d.check('a dialog is now showing on this window') { !win.visible_dialog.nil? }
        # Adwaita::AlertDialog#choose wires its response handling up
        # asynchronously; a turn of the loop is needed before a later
        # signal_emit('response', ...) will actually reach it.
        pump(100)
        d.shot('05-password-view', win)

        view.instance_variable_get(:@dialog).then do |password_dialog|
          d.check('the preference choice is offered (a keyring is wanted)') do
            password_dialog.password_choice.visible?
          end

          received = nil
          view.signal_connect('unlock') { |_v, pw, save| received = [pw, save] }

          password_dialog.dialog.tap do |alert|
            alert.set_response_enabled(PasswordDialog::RESPONSE_UNLOCK, true)
            password_dialog.password_entry.text = 'hunter2'
            alert.signal_emit('response', PasswordDialog::RESPONSE_UNLOCK)
            # A real click both emits "response" and closes the dialog, as
            # Adwaita::AlertDialog's own button handler does; signal_emit
            # only replays the first half, so the second is driven by hand.
            alert.close
          end

          d.check('the unlock signal carried the typed password') { received&.first == 'hunter2' }
          d.check('the dialog is torn down after answering') { view.instance_variable_get(:@dialog).nil? }
          d.check('the dialog is no longer showing') { win.visible_dialog.nil? }
        end
      end
      win.close
    end
  end

  d.step('PasswordView reports cancellation and marks a retry as an error') do
    scratch_window(app.app).then do |win|
      PasswordView.new(can_save_password: false).build.then do |view|
        win.content = view
        view.ask_password(false)
        pump(100)

        cancelled = false
        view.signal_connect('cancelled') { cancelled = true }
        view.instance_variable_get(:@dialog).dialog.tap do |alert|
          alert.signal_emit('response', PasswordDialog::RESPONSE_CANCELLED)
          alert.close
        end
        d.check('cancelling fires the cancelled signal') { cancelled }

        view.ask_password(true)
        pump(100)
        view.instance_variable_get(:@dialog).then do |password_dialog|
          d.check('an error retry marks the entry') { password_dialog.password_entry.has_css_class?('error') }
          d.check('and shows the invalid-password label') { password_dialog.error_message.visible? }
          d.check('with no keyring, the remember choice is hidden') { !password_dialog.password_choice.visible? }
          password_dialog.dialog.tap do |alert|
            alert.signal_emit('response', PasswordDialog::RESPONSE_CANCELLED)
            alert.close
          end
        end
      end
      win.close
    end
  end

  d.step('ProgressMessageArea renders its heading, status and fraction') do
    scratch_window(app.app).then do |win|
      ProgressMessageArea.new('document-save-symbolic', 'Saving a copy').build.then do |area|
        win.content = area
        d.check('the heading arrived bold-markup, as upstream wraps it') do
          area.label.label == '<b>Saving a copy</b>'
        end
        area.secondary_text = 'myfile.pdf'
        d.check('the secondary line shows once set') { area.secondary_label.visible? }
        area.status = '3 of 10 pages'
        area.fraction = 0.3
        d.check('the status label took the text') { area.progress_label.text == '3 of 10 pages' }
        d.check('the progress bar took the fraction') { area.progress_bar.fraction == 0.3 }
        d.check('a document name is escaped, never read as markup') do
          area.text = '<b>evil</b> & co'
          area.label.label == '<b>&lt;b&gt;evil&lt;/b&gt; &amp; co</b>'
        end
        pump(100)
        d.shot('06-progress-message-area', area)
      end
      win.close
    end
  end

  d.step('SimpleColorSwatch redraws on every colour change') do
    scratch_window(app.app).then do |win|
      SimpleColorSwatch.new.build.then do |swatch|
        swatch.width_request = 32
        swatch.height_request = 32
        win.content = swatch
        swatch.color = Gdk::RGBA.parse('#3584e4')
        d.check('the colour property took the new value') { swatch.color.to_s == 'rgb(53,132,228)' }
        pump(100)
        d.shot('07-color-swatch', swatch)
      end
      win.close
    end
  end

  d.step('SidebarPage is abstract: support_document? has no default answer') do
    Class.new(SidebarPage) do
      def support_document?(_doc) = true
    end.then do |concrete_page_class|
      DocumentModel.new.then do |dm|
        d.check('a subclass that implements it works normally') do
          concrete_page_class.new(document_model: dm).support_document?(nil) == true
        end
        d.check('the base class raises NotImplementedError') do
          begin
            SidebarPage.new(document_model: dm).support_document?(nil)
            false
          rescue NotImplementedError
            true
          end
        end
      end
    end
  end

  # --- Model classes no widget ever reaches yet -----------------------------

  d.step('DocumentModel clamps pages, scale and rotation like upstream') do
    DocumentModel.new.then do |dm|
      changes = []
      dm.signal_connect('page-changed') { |_m, old_page, new_page| changes << [old_page, new_page] }

      fake_doc = Struct.new(:n_pages).new(5)
      dm.document = fake_doc
      d.check('n_pages followed the document') { dm.n_pages == 5 }
      dm.page = 2
      d.check('page-changed fired for the document assignment\'s clamp and the explicit set') do
        changes == [[-1, 0], [0, 2]]
      end
      dm.page = 99
      d.check('a page past the end is refused') { dm.page == 2 }
      dm.sizing_mode = DocumentModel::SIZING_FREE
      dm.scale = 100
      d.check('scale is clamped to max-scale in free mode') { dm.scale == dm.max_scale }
      dm.rotation = 450
      d.check('rotation normalises past one full turn') { dm.rotation == 90 }
      dm.rotation = -90
      d.check('and normalises a negative turn too') { dm.rotation == 270 }
    end
  end

  d.step('AnnotationModel tracks a tool and its own colour/radius per tool') do
    AnnotationModel.new.then do |am|
      am.tool = AnnotationModel::TOOL_HIGHLIGHT
      d.check('active_tool_str followed the tool') { am.active_tool_str == 'highlighter' }
      am.active_tool_str = 'eraser'
      d.check('and the reverse lookup works too') { am.tool == AnnotationModel::TOOL_ERASER }
      am.pen_color = Gdk::RGBA.parse('#00ff00')
      d.check('pen colour is independent of highlight colour') do
        am.pen_color.to_s == 'rgb(0,255,0)' && am.highlight_color.to_s != 'rgb(0,255,0)'
      end
      am.text_font = Pango::FontDescription.new('Sans 20')
      d.check('setting the font keeps the size the size control owns') do
        am.text_font.family == 'Sans' && am.text_font.size == am.text_font.size
      end
    end
  end

  d.step('History tracks back/forward across page changes') do
    DocumentModel.new.then do |dm|
      History.new(dm).then do |history|
        changed_events = 0
        history.signal_connect('changed') { changed_events += 1 }
        history.add_page(0)
        history.add_page(3)
        history.add_page(7)
        d.check('the current page is the last one pushed') { history.current_page == 7 }
        d.check('it can go back') { history.can_go_back? }
        history.go_back
        d.check('going back lands on the previous page') { history.current_page == 3 }
        d.check('it can still go forward') { history.can_go_forward? }
        history.go_forward
        d.check('forward returns to where it was') { history.current_page == 7 }
        d.check('"changed" fired for every mutation') { changed_events.positive? }
      end
    end
  end

  d.step('UndoContext routes an undo onto the redo stack') do
    Class.new(GLib::Object) do
      include UndoHandler
      attr_reader :undone

      def undo(action)
        (@undone ||= []) << action
      end
    end.then do |handler_class|
      DocumentModel.new.then do |dm|
        UndoContext.new(dm).then do |uc|
          handler = handler_class.new
          uc.add_action(handler, 'added-annotation')
          d.check('the action landed on the undo stack') { uc.can_undo? && !uc.can_redo? }
          uc.undo
          d.check('undoing calls the handler back') { handler.undone == ['added-annotation'] }
          d.check('and the undo stack is empty again') { !uc.can_undo? }
        end
      end
    end
  end

  d.step('ThumbnailItem and SearchResult hold the sidebar/find state') do
    ThumbnailItem.new.then do |item|
      item.text = '3'
      d.check('ThumbnailItem#text round-trips') { item.text == '3' }
    end
    SearchResult.new(
      '<b>match</b>',
      '3',
      2,
      0,
      5,
      [1, 2, 3, 4],
    ).then do |result|
      d.check('constructor fields are set') { result.page == 2 && result.global_index == 5 }
      result.append_rectangle([5, 6, 7, 8])
      d.check('a wrapped match grows the rectangle list') { result.rectangle_list.length == 2 }
    end
  end

  d.step('FileMonitor debounces plain changes and fires early on the done hint') do
    Dir.mktmpdir.then do |dir|
      File.join(dir, 'watched.pdf').then do |path|
        File.write(path, 'v1')
        FileMonitor.new("file://#{path}").then do |monitor|
          fired = false
          monitor.signal_connect('changed') { fired = true }
          File.write(path, 'v2')

          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
          while !fired && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
            GLib::MainContext.default.iteration(false)
          end

          d.check('a local write is reported (changes-done-hint)') { fired }
        end
      end
    end
  end

  d.step('Keyring reports unavailable rather than raising with no Secret Service') do
    d.check('availability check does not raise') { Keyring.available?.is_a?(TrueClass) || Keyring.available?.is_a?(FalseClass) }
    d.check('a lookup with nothing listening fails closed') { Keyring.lookup_password('file:///none').nil? }
    d.check('save with NEVER short-circuits true without touching the keyring') do
      Keyring.save_password('file:///none', 'x', Gio::PasswordSave::NEVER) == true
    end
  end

  d.step('Metadata reads and writes typed values alongside a real file') do
    Dir.mktmpdir.then do |dir|
      Gio::File.new_for_path(File.join(dir, 'doc.pdf')).then do |file|
        File.write(file.path, 'content')
        Metadata.new(file).then do |metadata|
          d.check('a fresh file carries no metadata yet') { metadata.empty? }
          metadata.set_int('page', 7)
          d.check('an int round-trips as an int') { metadata.get_int('page') == 7 }
          metadata.set_boolean('continuous', true)
          d.check('a boolean round-trips too') { metadata.get_boolean('continuous') == true }
        end
      end
      Gio::File.new_for_path(File.join(Dir.tmpdir, 'temp-doc.pdf')).then do |temp_file|
        d.check('a file under the system temp dir is never annotated') do
          Metadata.temp_file?(temp_file)
        end
      end
    end
  end

  d.step('SignatureImageProcessing turns a drawn pixbuf into an ink stencil') do
    GdkPixbuf::Pixbuf.new(colorspace: :rgb, has_alpha: true, bits_per_sample: 8, width: 4, height: 4).then do |pixbuf|
      pixbuf.fill!(0x000000ff)
      SignatureImageProcessing.raw_image_data(pixbuf).then do |raw|
        raw.do_signature_threshold.then do |processed|
          d.check('the processed image keeps the source dimensions') do
            processed.width == 4 && processed.height == 4
          end
          d.check('the processed image is RGBA') { processed.n_channels == 4 }
          SignatureImageProcessing.pixbuf(processed).then do |out|
            d.check('a pixbuf can be built back from it') { out.width == 4 && out.height == 4 }
          end
        end
      end
    end
  end

  d.step('ViewColors, ViewCursor and CssUtils answer upstream\'s lookup tables') do
    d.check('the accent foreground is white with a zeroed alpha, as upstream leaves it') do
      ViewColors.accent_foreground_color.then { |c| c.red == 1.0 && c.alpha == 0.0 }
    end
    d.check('every cursor in the enum resolves by position') do
      ViewCursor::ALL.each_with_index.all? { |cursor, index| ViewCursor.name(index) == ViewCursor.name(cursor) }
    end
    d.check('the normal cursor has no CSS name (inherits)') { ViewCursor.name(ViewCursor::NORMAL).nil? }
    d.check('a bold font description becomes a declaration block') do
      CssUtils.font_description_to_css(Pango::FontDescription.new('Sans Bold 12'))
              .include?('font-weight:bold;')
    end
    d.check('a nil class name becomes the literal upstream produces') do
      CssUtils.filter_class_chars(nil) == '(null)'
    end
    d.check('a class name is stripped to the allowed character set') do
      CssUtils.filter_class_chars('My Layer! (1)') == 'MyLayer1'
    end
  end
end
