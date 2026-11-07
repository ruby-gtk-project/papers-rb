# frozen_string_literal: true

require 'adwaita'
require_relative 'document_model'

# PageSelector is the page-number entry and "of N" label the header bar
# shows, letting the reader type a page (or label) to jump to, or scroll the
# entry to step through pages.
#
# Ported from upstream's shell/src/page_selector.rs and
# shell/resources/pps-page-selector.blp. Upstream emits "activate-link" with
# a PpsLink built from the typed text; this port has no PpsLink/PpsLinkDest
# backend (DocumentModel's own comment explains why), so, following the same
# adaptation history.rb makes for "activate-link", this emits "activate_page"
# with the page DocumentModel::page_by_label= actually resolved to.
#
class PageSelector < Gtk::Box
  type_register

  define_signal(
    'activate_page',
    GLib::Signal::RUN_LAST,
    nil,
    nil,
    Integer,
  )

  def initialize
    super()
    self.orientation = :horizontal
    add_css_class('numeric')
    self.sensitive = false
  end

  def build
    tap do |selector|
      selector.append(entry)
      selector.append(label)

      entry.tap do |e|
        e.set_direction(:ltr)
        e.max_width_chars = 0
        e.width_chars = 3
        e.xalign = 0.9
        e.signal_connect('activate') { activated }
        e.add_controller(scroll_controller)
        e.add_controller(focus_controller)
      end

      label.tap do |l|
        l.max_width_chars = 0
        l.width_chars = 5
        l.sensitive = false
      end
    end
  end

  def grab_focus = entry.grab_focus

  def signal_do_activate_page(_page) = nil

  attr_reader :model

  def model=(model)
    clear_model
    @document_notify_handler = model.signal_connect('notify::document') { update_document }
    @page_changed_handler = model.signal_connect('page-changed') { |_m, _old, new_page| set_current_page(new_page) }
    @model = model
  end

  private

    def entry = @entry ||= Gtk::Entry.new
    def label = @label ||= Gtk::Label.new

    def scroll_controller
      @scroll_controller ||= Gtk::EventControllerScroll.new(
        Gtk::EventControllerScrollFlags::VERTICAL | Gtk::EventControllerScrollFlags::DISCRETE,
      ).tap do |controller|
        controller.signal_connect('scroll') { |_ctrl, _dx, dy| page_scrolled(dy) }
      end
    end

    def focus_controller
      @focus_controller ||= Gtk::EventControllerFocus.new.tap do |controller|
        controller.signal_connect('leave') { focused_out }
      end
    end

    def document = @model&.document

    def clear_model
      @model.then do |model|
        unless model.nil?
          model.signal_handler_disconnect(@document_notify_handler)
          model.signal_handler_disconnect(@page_changed_handler)
        end
      end
      @model = nil
      @document_notify_handler = nil
      @page_changed_handler = nil
    end

    def activated
      @model.then do |model|
        current_page = model.page
        model.page_by_label = entry.text
        signal_emit('activate_page', model.page)
        set_current_page(current_page) if current_page == model.page
      end
    end

    # Upstream's direction comes off the raw scroll event; this binding's
    # "scroll" signal already hands the delta, so the sign of dy serves the
    # same purpose without reaching into the current event.
    def page_scrolled(dy)
      @model.then do |model|
        page = model.page
        page += 1 if dy.positive? && document && page < document.n_pages - 1
        page -= 1 if dy.negative? && page.positive?
        model.page = page
      end
      true
    end

    def focused_out
      @model.then { |model| set_current_page(model.page) }
      entry.xalign = 0.9
      update_max_width
    end

    def update_document
      self.sensitive = !document.nil? && document.n_pages > 0
      @model.then { |model| set_current_page(model.page) }
      update_max_width
    end

    def set_current_page(page)
      (page >= 0).then do |valid|
        if valid
          entry.text = document ? page_label(page) : ''
          entry.position = -1
          update_pages_label(page)
        end
      end
    end

    def page_label(page)
      document.respond_to?(:page_label) ? (document.page_label(page) || '') : (page + 1).to_s
    end

    def has_text_page_labels? = document.respond_to?(:has_text_page_labels?) && document.has_text_page_labels?

    def show_page_number_in_pages_label?(page)
      has_text_page_labels? && (page + 1).to_s != entry.text
    end

    def update_pages_label(page)
      document.then do |doc|
        n_pages = doc.n_pages
        label.text = if show_page_number_in_pages_label?(page)
          "(#{page + 1} of #{n_pages})"
        else
          "of #{n_pages}"
        end
      end
    end

    def update_max_width
      document.then do |doc|
        n_pages = doc.n_pages
        max_page_numeric_label = n_pages.to_s.length

        max_label_len = if has_text_page_labels?
          "(#{n_pages} of #{n_pages})".length - 2
        else
          "of #{n_pages}".length
        end
        label.width_chars = max_label_len

        entry_width = doc.respond_to?(:max_label_len) ? doc.max_label_len.clamp(max_page_numeric_label, 12) : max_page_numeric_label
        entry.width_chars = entry_width
      end
    end
end
