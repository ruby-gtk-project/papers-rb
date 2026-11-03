# frozen_string_literal: true

require 'adwaita'

# PasswordDialog asks for a locked document's password.
#
# Ported from upstream's shell/resources/pps-password-dialog.blp. That file has
# no source file of its own: it declares a free-standing Adw.AlertDialog, and
# the password view builds one from it with a Gtk::Builder each time it needs
# to ask. This class is that dialog — its responses, its entry and the two
# check buttons — with #build returning the dialog itself.
#
# The dialog's actions live in the password view's "password" action group,
# which the view inserts before presenting the dialog; the check buttons name
# "password.preference" and carry the two states as their action targets,
# which is how a radio pair is spelled with a stateful action.
#
class PasswordDialog
  RESPONSE_CANCELLED = 'cancelled'
  RESPONSE_UNLOCK = 'unlock'

  PREFERENCE_ACTION = 'password.preference'
  PREFERENCE_NEVER = 'never'
  PREFERENCE_PERMANENTLY = 'permanently'

  # error: the previous password was wrong, so the entry is marked and the
  #   "Invalid password" label shown.
  # can_save_password: whether there is a keyring to save the password in. The
  #   choice between forgetting it and keeping it is hidden when there is not,
  #   exactly as upstream hides it in a build without keyring support.
  def initialize(error: false, can_save_password: false)
    @error = error
    @can_save_password = can_save_password
  end

  def build
    dialog.tap do |alert|
      alert.extra_child = content_box

      content_box.tap do |box|
        box.append(password_entry)
        box.append(error_box)
        box.append(password_choice)

        error_box.append(error_message)

        password_choice.tap do |choice|
          choice.append(forget_button)
          choice.append(remember_button)
        end
      end

      if @error
        password_entry.add_css_class('error')
        error_message.visible = true
      end

      if @can_save_password
        password_choice.visible = true
      end
    end
  end

  # The password typed in. Read when the dialog answers "unlock".
  def password = password_entry.text

  # The Unlock response stays disabled until something has been typed, which
  # is what upstream's changed handler does.
  def track_entry
    password_entry.signal_connect('changed') do |entry|
      dialog.set_response_enabled(RESPONSE_UNLOCK, !entry.text.empty?)
    end
  end

  def dialog
    @dialog ||= Adwaita::AlertDialog.new('Password Required', '').tap do |alert|
      alert.body_use_markup = true
      alert.add_response(RESPONSE_CANCELLED, 'Cancel')
      alert.add_response(RESPONSE_UNLOCK, 'Unlock')
      alert.set_response_enabled(RESPONSE_UNLOCK, false)
      alert.close_response = RESPONSE_CANCELLED
      alert.default_response = RESPONSE_UNLOCK
    end
  end

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.halign = :center
    end
  end

  def password_entry
    @password_entry ||= Gtk::PasswordEntry.new.tap do |entry|
      entry.placeholder_text = 'Password'
      entry.show_peek_icon = true
      entry.activates_default = true
      entry.width_chars = 32
      entry.margin_bottom = 10
    end
  end

  def error_box
    @error_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.halign = :center
    end
  end

  def error_message
    @error_message ||= Gtk::Label.new('Invalid password').tap do |label|
      label.visible = false
      label.add_css_class('error')
    end
  end

  def password_choice
    @password_choice ||= Gtk::Box.new(:vertical, 6).tap do |box|
      box.halign = :center
      box.visible = false
    end
  end

  def forget_button
    @forget_button ||= Gtk::CheckButton.new.tap do |button|
      button.label = 'Forget password _immediately'
      button.use_underline = true
      button.set_detailed_action_name("#{PREFERENCE_ACTION}::#{PREFERENCE_NEVER}")
    end
  end

  def remember_button
    @remember_button ||= Gtk::CheckButton.new.tap do |button|
      button.label = 'Remember _forever'
      button.use_underline = true
      button.set_detailed_action_name("#{PREFERENCE_ACTION}::#{PREFERENCE_PERMANENTLY}")
    end
  end
end
