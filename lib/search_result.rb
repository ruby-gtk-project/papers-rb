# frozen_string_literal: true

require 'adwaita'

# SearchResult is one match from a document-wide search: the text around it,
# the page it is on and the rectangles to highlight.
#
# Ported from upstream's libview/context/pps-search-result.c. It is a
# GLib::Object here as it is a GObject there, so the find sidebar's ListView
# can hold these in a Gio::ListStore. Everything about it is set at
# construction except the rectangle list, which the search job appends to as
# it finds the rest of a match that wraps across lines.
#
class SearchResult < GLib::Object
  type_register

  # markup: the match with its surrounding text, Pango markup with the match
  #   itself emphasised, which is what the sidebar row displays.
  # label: the page's label, displayed beside the markup.
  # page: the zero-based page index the match is on.
  # index: the match's position among the matches on that page.
  # global_index: its position among all the matches in the document.
  attr_reader :markup, :label, :page, :index, :global_index

  # Upstream's constructor takes one rectangle and starts the list with a copy
  # of it. The rectangles belong to the search job, which does not reuse them,
  # so they are held rather than copied here.
  def initialize(markup, label, page, index, global_index, rectangle)
    super()
    @markup = markup
    @label = label
    @page = page
    @index = index
    @global_index = global_index
    @rectangles = [rectangle]
  end

  def rectangle_list = @rectangles

  # Only the search job appends, and only while assembling a match that runs
  # past the end of a line.
  def append_rectangle(rectangle)
    @rectangles << rectangle
  end
end
