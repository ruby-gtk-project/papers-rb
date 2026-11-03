# frozen_string_literal: true

require 'adwaita'
require_relative 'password_dialog'

# PasswordView is the page the window shows when the document it opened is
# locked: a status page explaining why nothing is on screen, and a button that
# asks for the password.
#
# Ported from upstream's shell/src/password_view.rs and
# shell/resources/pps-password-view.blp. The view owns the "password" action
# group holding the stateful "preference" action the dialog's two check
# buttons drive, creates the dialog on demand, and reports the answer as one
# of two signals: "unlock" with the password and how long to keep it, or
# "cancelled".
#
# can_save_password mirrors upstream's with-keyring build feature. Without a
# keyring there is nowhere to keep a password, so the choice is hidden and the
# preference reported is always Never.
#
class PasswordView < Adwaita::Bin
  type_register

  define_signal(
    'unlock',
    GLib::Signal::RUN_LAST,
    nil,
    nil,
    String,
    Gio::PasswordSave,
  )
  define_signal(
    'cancelled',
    GLib::Signal::RUN_LAST,
    nil,
    nil,
  )

  install_property(
    GLib::Param::String.new(
      'filename',
      'Filename',
      'The name of the locked document',
      '',
      GLib::Param::READWRITE,
    ),
  )

  PREFERENCES = {
    PasswordDialog::PREFERENCE_NEVER       => Gio::PasswordSave::NEVER,
    PasswordDialog::PREFERENCE_PERMANENTLY => Gio::PasswordSave::PERMANENTLY,
  }.freeze

  attr_reader :filename

  def initialize(can_save_password: false)
    super()
    @filename = ''
    @can_save_password = can_save_password
    @dialog = nil
  end

  def signal_do_unlock(_password, _save) = nil
  def signal_do_cancelled = nil

  def build
    tap do |view|
      view.child = toolbar_view

      toolbar_view.tap do |bars|
        bars.add_top_bar(header_bar)
        bars.content = status_page

        header_bar.title_widget = window_title
        status_page.child = unlock_button

        unlock_button.signal_connect('clicked') { ask_password(false) }
      end

      view.insert_action_group('password', action_group)
      action_group.add_action(preference_action)
    end
  end

  def filename=(filename)
    @filename = filename
    notify('filename')
  end

  # Asks for the password, unless the dialog is already up. error marks the
  # entry and shows the "Invalid password" label, which is how the window asks
  # again after the document rejected the last answer.
  def ask_password(error)
    @dialog.nil?.then do |none_up|
      if none_up
        create_dialog(error)
      end
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new
  def window_title = @window_title ||= Adwaita::WindowTitle.new('Password Required', '')
  def action_group = @action_group ||= Gio::SimpleActionGroup.new

  def status_page
    @status_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'dialog-password-symbolic'
      page.title = 'Password Required'
      page.description =
        'This document is locked and can only be read by entering the correct password'
    end
  end

  def unlock_button
    @unlock_button ||= Gtk::Button.new.tap do |button|
      button.halign = :center
      button.use_underline = true
      button.label = '_Unlock Document'
      button.add_css_class('pill')
    end
  end

  # Stateful, with the state being whichever of the two check buttons is
  # ticked. It starts on "never" and is put back there after every answer.
  def preference_action
    @preference_action ||= Gio::SimpleAction.new(
      'preference',
      GLib::VariantType.new('s'),
      GLib::Variant.new(PasswordDialog::PREFERENCE_NEVER),
    )
  end

  private

    def create_dialog(error)
      PasswordDialog.new(error: error, can_save_password: @can_save_password).tap do |dialog|
        @dialog = dialog

        dialog.build.tap do |alert|
          alert.body = body_text
          alert.insert_action_group('password', action_group)
          dialog.track_entry

          alert.choose(self) do |_source, result|
            handle_response(alert.choose_finish(result))
          end
        end
      end
    end

    def body_text
      "The document “#{@filename}” is locked and requires " \
        'a password before it can be opened'
    end

    # Reports the answer, then puts the preference back to "never" so the next
    # document starts from the safe choice.
    def handle_response(response)
      @dialog.then do |dialog|
        @dialog = nil

        case response
        when PasswordDialog::RESPONSE_UNLOCK
          password_save.tap do |save|
            preference_action.set_state(GLib::Variant.new(PasswordDialog::PREFERENCE_NEVER))
            signal_emit('unlock', dialog.password, save)
          end
        when PasswordDialog::RESPONSE_CANCELLED
          signal_emit('cancelled')
        end
      end
    end

    # Without a keyring the state is ignored and the password is never kept.
    # The Ruby bindings hand back the stateful action's state as the string it
    # holds rather than as a GLib::Variant.
    def password_save
      if @can_save_password
        PREFERENCES.fetch(preference_action.state.to_s, Gio::PasswordSave::NEVER)
      else
        Gio::PasswordSave::NEVER
      end
    end
end
