# frozen_string_literal: true

require 'adwaita'
require_relative 'document_model'

# History is the back/forward navigation stack for the open document: every
# page the window has visited, and where "current" sits among them.
#
# Ported from upstream's libview/context/pps-history.c. Upstream's entries are
# PpsLink objects wrapping a PpsLinkDest, because a link followed in the
# document (a named destination, a page label) is resolved to a page number
# through the open PpsDocument before it is pushed. This port has no document
# backend to resolve those against — DocumentModel's "document" is a bare
# GLib::Object, as its own comment explains — so an entry here is simply the
# page number upstream's pps_history_get_current_page ends up computing, and
# "activate-link" becomes "activate-page", carrying that integer instead of a
# PpsLink. Everything else — the list, the cursor, pruning to MAX_LENGTH,
# freeze/thaw, clearing on a new document — is the same shape as upstream.
#
class History < GLib::Object
  type_register

  MAX_LENGTH = 32

  # Emitted whenever the list or the cursor changes, so a window can
  # re-evaluate its back/forward actions.
  define_signal('changed', GLib::Signal::RUN_LAST, nil, nil)

  # Emitted when go_back, go_forward or go_to_page moves the cursor onto an
  # entry, with the page it landed on.
  define_signal(
    'activate_page',
    GLib::Signal::RUN_LAST,
    nil,
    nil,
    Integer,
  )

  install_property(
    GLib::Param::Object.new(
      'document-model',
      'Document Model',
      'The document model this history follows',
      DocumentModel,
      GLib::Param::READWRITE,
    ),
  )

  attr_reader :document_model

  def initialize(document_model)
    super()
    @document_model = document_model
    @list = []
    @current_index = nil
    @frozen = 0

    document_model.signal_connect('notify::document') { document_changed }
  end

  def signal_do_changed = nil
  def signal_do_activate_page(_page) = nil

  def frozen? = @frozen > 0

  def freeze = @frozen += 1

  def thaw
    if frozen?
      @frozen -= 1
    else
      raise(RuntimeError, 'History#thaw called while not frozen')
    end
  end

  # Pushes page onto the list as the new current entry, dropping everything
  # that was ahead of the old current entry — upstream's truncate-at-current
  # before appending. A no-op while frozen, or when page is already current,
  # which is how activating a link that lands back where it started avoids
  # growing the list.
  def add_page(page)
    unless frozen? || current_page == page
      @list = @list.first(@current_index.nil? ? 0 : @current_index + 1)
      @list << page
      @current_index = @list.length - 1

      prune
      signal_emit('changed')
    end
  end

  # The page the cursor is on, or nil with an empty list.
  def current_page = @current_index.nil? ? nil : @list[@current_index]

  def can_go_back?
    if frozen?
      false
    elsif current_page && (document_model.page - current_page).abs > 1
      true
    else
      !@current_index.nil? && @current_index.positive?
    end
  end

  def go_back
    if can_go_back?
      @current_index -= 1
      activate_current
    end
  end

  def can_go_forward?
    !frozen? && !@current_index.nil? && @current_index < @list.length - 1
  end

  def go_forward
    if can_go_forward?
      @current_index += 1
      activate_current
    end
  end

  # Goes to page, if it is in the history. Returns whether it was.
  def go_to_page(page)
    if frozen?
      false
    else
      index = @list.rindex(page)

      if index.nil?
        false
      else
        @current_index = index
        activate_current
        true
      end
    end
  end

  # The pages behind the cursor, oldest first.
  def back_list = @current_index.nil? ? [] : @list[0...@current_index]

  # The pages ahead of the cursor.
  def forward_list = @current_index.nil? ? [] : @list[(@current_index + 1)..]

  private

    # Caps the list at MAX_LENGTH entries by dropping the oldest ones,
    # exactly as upstream's pps_history_prune walks back MAX_LENGTH steps
    # from current and throws away everything older.
    def prune
      if @list.length > MAX_LENGTH
        drop = @list.length - MAX_LENGTH
        @list = @list.drop(drop)
        @current_index -= drop
      end
    end

    def activate_current
      freeze
      signal_emit('activate-page', current_page)
      thaw

      signal_emit('changed')
    end

    def document_changed
      @list = []
      @current_index = nil
      add_page(document_model.page)
    end
end
