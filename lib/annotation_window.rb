# frozen_string_literal: true

require 'adwaita'
require 'libspelling'

# AnnotationWindow is the small floating popup used to type or edit a text
# annotation's note.
#
# Ported from upstream's libview/pps-annotation-window.c: an Adw.HeaderBar
# with a title label naming the annotation, over a scrolled text view
# holding its contents.
#
# Upstream attaches a SpellingTextBufferAdapter to a GtkSourceView so a
# misspelled word gets the red squiggle and a right-click correction menu
# (gtk_text_view_set_extra_menu / spelling_text_buffer_adapter_get_menu_model,
# gtk_widget_insert_action_group (text_view, "spelling", ...)). That adapter
# is unreachable from here: Spelling::TextBufferAdapter#initialize demands a
# GtkSourceBuffer —
#
#   Spelling::TextBufferAdapter#initialize(buffer: interface(GtkSourceBuffer),
#     checker: interface(Spelling::Checker))
#
# — and ruby-gnome has no GtkSource binding in this port's dependency set (no
# `gtksourceview5`/`gtksourceview4` gem), so a GtkSourceBuffer cannot be
# constructed to hand it. What this class calls instead is the checker the
# adapter would have used underneath (spelling_checker_get_default in C):
# Spelling::Checker.default, asked word-by-word as the buffer changes, with
# a misspelled word getting the "error" css class — the same class
# password_dialog.rb marks a rejected password with — in place of the
# native squiggly underline GtkSourceView's own rendering would draw through
# the adapter.
#
class AnnotationWindow < Gtk::Window
  type_register

  # title: the annotation's label, shown in the header bar.
  # contents: its initial text.
  # enable_spellchecking: Settings#default's "enable-spellchecking" key;
  #   upstream gates the whole adapter on the same preference
  #   (window->enable_spellchecking in pps-annotation-window.c).
  def initialize(title: '', contents: '', enable_spellchecking: true)
    super()
    @title_text = title
    @initial_contents = contents
    @enable_spellchecking = enable_spellchecking
  end

  def build
    tap do |window|
      window.add_css_class('pps-annotation-window')
      window.can_focus = true
      window.titlebar = headerbar
      window.child = vbox

      headerbar.tap do |bar|
        bar.title_widget = title_label
      end

      vbox.tap do |box|
        box.append(scroller)
      end

      scroller.tap do |sw|
        sw.child = text_view
      end

      text_buffer.text = @initial_contents

      if @enable_spellchecking
        text_buffer.signal_connect('changed') { check_spelling }
      end
    end
  end

  # The text currently in the buffer, read when the window closes — mirrors
  # upstream's pps_annotation_window_sync_contents.
  def contents = text_buffer.text

  def headerbar = @headerbar ||= Adwaita::HeaderBar.new

  def title_label
    @title_label ||= Gtk::Label.new(@title_text).tap do |label|
      label.halign = :fill
      label.hexpand = true
    end
  end

  def vbox = @vbox ||= Gtk::Box.new(:vertical, 0)

  def scroller
    @scroller ||= Gtk::ScrolledWindow.new.tap do |sw|
      sw.valign = :fill
      sw.vexpand = true
    end
  end

  def text_view
    @text_view ||= Gtk::TextView.new(text_buffer).tap do |view|
      view.cursor_visible = true
      view.wrap_mode = :word
    end
  end

  def text_buffer = @text_buffer ||= Gtk::TextBuffer.new

  # The checker upstream's adapter would hold: spelling_checker_get_default.
  def checker = @checker ||= Spelling::Checker.default

  def error_tag = @error_tag ||= text_buffer.create_tag('misspelled', underline: :error)

  private

    # Manual stand-in for what SpellingTextBufferAdapter does automatically:
    # re-check every word in the buffer and tag the ones the checker rejects.
    def check_spelling
      text_buffer.remove_tag(error_tag, text_buffer.start_iter, text_buffer.end_iter)

      whole_text = text_buffer.text
      offset = 0
      whole_text.scan(/\S+/) do |word|
        word_start = whole_text.index(word, offset)
        offset = word_start + word.length

        next if checker.check_word(word, -1)

        text_buffer.apply_tag(
          error_tag,
          text_buffer.get_iter_at(offset: word_start),
          text_buffer.get_iter_at(offset: offset),
        )
      end
    end
end
