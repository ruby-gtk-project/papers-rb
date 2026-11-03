# frozen_string_literal: true

require 'adwaita'
require_relative 'document_model'

# SidebarPage is the base class of the sidebar's pages — thumbnails, outline,
# annotations, attachments and layers.
#
# Ported from upstream's shell/src/sidebar_page.rs, which is an abstract
# Adw.Bin subclass with two construct-only properties and one virtual method.
# It carries the document model every page reads, a reference back to the
# sidebar so a page can ask it to show the document again after an activation,
# and #support_document?, which the sidebar calls to decide whether to offer
# the page for the document that is open.
#
# Abstract in the same sense as upstream's ABSTRACT = true: instantiating it
# is a mistake, and #support_document? has no default answer.
#
class SidebarPage < Adwaita::Bin
  type_register

  install_property(
    GLib::Param::Object.new(
      'document-model',
      'Document Model',
      'The document model the page reads',
      DocumentModel,
      GLib::Param::READWRITE,
    ),
  )

  # The sidebar is declared over GLib::Object rather than the Sidebar class,
  # because a page is constructed by the sidebar and so is compiled before it.
  install_property(
    GLib::Param::Object.new(
      'sidebar',
      'Sidebar',
      'The sidebar holding this page',
      GLib::Object,
      GLib::Param::READWRITE,
    ),
  )

  attr_reader :document_model, :sidebar

  def initialize(document_model:, sidebar: nil)
    super()
    @document_model = document_model
    @sidebar = sidebar
  end

  # Asks the sidebar to put the document back in front — what a page does
  # after the user activates one of its rows, so following a link or opening
  # an attachment does not leave the sidebar in the way on a narrow window.
  def navigate_to_view
    @sidebar.then do |sidebar|
      unless sidebar.nil?
        sidebar.signal_emit('navigated-to-view')
      end
    end
  end

  # Whether this page has anything to show for the document. The sidebar hides
  # a page that answers false — a document with no outline gets no outline
  # page.
  def support_document?(_document)
    raise(NotImplementedError, "#{self.class}#support_document?")
  end
end
