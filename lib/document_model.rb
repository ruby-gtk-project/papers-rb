# frozen_string_literal: true

require 'adwaita'
require_relative 'annotation_model'

# DocumentModel is the state every view of a document shares: which document
# is open, which page is current, the zoom, the rotation, the sizing mode and
# the page layout.
#
# Ported from upstream's libview/context/pps-document-model.c. It keeps the
# property names and the "page-changed" signal, so the widgets bind to the
# same strings; what differs is the three enum-typed properties. Upstream's
# PpsSizingMode, PpsPageLayout and PpsAnnotationEditingState get GTypes from
# a generated pps-view-type-builtins.c, which this port has no equivalent of,
# so the properties are ints over the same values and the accessors take and
# return those values.
#
class DocumentModel < GLib::Object
  type_register

  # PpsSizingMode
  SIZING_FIT_PAGE = 0
  SIZING_FIT_WIDTH = 1
  SIZING_FREE = 2
  SIZING_AUTOMATIC = 3

  # PpsPageLayout
  PAGE_LAYOUT_SINGLE = 0
  PAGE_LAYOUT_DUAL = 1
  PAGE_LAYOUT_AUTOMATIC = 2

  # PpsAnnotationEditingState, a flags type
  ANNOTATION_EDITING_STATE_NONE = 0
  ANNOTATION_EDITING_STATE_INK = 1
  ANNOTATION_EDITING_STATE_TEXT = 2
  ANNOTATION_EDITING_STATE_STAMP = 4
  ANNOTATION_EDITING_STATE_INSERT_TEXT = 8

  DEFAULT_MIN_SCALE = 0.25
  DEFAULT_MAX_SCALE = 5.0

  # The tolerance upstream compares scales with, so a scale that only differs
  # in the last bits is not a change.
  EPSILON = 0.000001

  MAX_INT = (2**31) - 1
  MAX_DOUBLE = Float::MAX

  define_signal(
    'page_changed',
    GLib::Signal::RUN_LAST,
    nil,
    nil,
    Integer,
    Integer,
  )

  install_property(
    GLib::Param::Object.new(
      'document',
      'Document',
      'The current document',
      GLib::Object,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Int.new(
      'page',
      'Page',
      'Current page',
      -1,
      MAX_INT,
      -1,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Int.new(
      'rotation',
      'Rotation',
      'Current rotation angle',
      0,
      360,
      0,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Boolean.new(
      'inverted-colors',
      'Inverted Colors',
      'Whether document is displayed with inverted colors',
      false,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Double.new(
      'scale',
      'Scale',
      'Current scale factor',
      0.0,
      MAX_DOUBLE,
      1.0,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Double.new(
      'min-scale',
      'Minimum Scale',
      'Minimum scale factor',
      0.0,
      MAX_DOUBLE,
      DEFAULT_MIN_SCALE,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Double.new(
      'max-scale',
      'Maximum Scale',
      'Maximum scale factor',
      0.0,
      MAX_DOUBLE,
      DEFAULT_MAX_SCALE,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Int.new(
      'sizing-mode',
      'Sizing Mode',
      'Current sizing mode',
      SIZING_FIT_PAGE,
      SIZING_AUTOMATIC,
      SIZING_FIT_WIDTH,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Int.new(
      'page-layout',
      'Page Layout',
      'Current page layout',
      PAGE_LAYOUT_SINGLE,
      PAGE_LAYOUT_AUTOMATIC,
      PAGE_LAYOUT_SINGLE,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Boolean.new(
      'continuous',
      'Continuous',
      'Whether document is displayed in continuous mode',
      true,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Boolean.new(
      'dual-odd-left',
      'Odd Pages Left',
      'Whether odd pages are displayed on left side in dual mode',
      false,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Boolean.new(
      'rtl',
      'Right to Left',
      'Whether the document is written from right to left',
      false,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Int.new(
      'annotation-editing-state',
      'Annotation Editing State',
      "Whether the document is being 'inked'",
      ANNOTATION_EDITING_STATE_NONE,
      MAX_INT,
      ANNOTATION_EDITING_STATE_NONE,
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Object.new(
      'annotation-model',
      'Annotation Model',
      'The current annotation model',
      AnnotationModel,
      GLib::Param::READWRITE,
    ),
  )

  attr_reader :annotation_model, :n_pages

  # Upstream's annotation-model property is construct-only, so it arrives with
  # the model; the constructor also takes an optional document, which is how
  # pps_document_model_new_with_document spells it.
  def initialize(document: nil, annotation_model: AnnotationModel.new)
    super()
    @page = -1
    @rotation = 0
    @scale = 1.0
    @sizing_mode = SIZING_FIT_WIDTH
    @page_layout = PAGE_LAYOUT_SINGLE
    @continuous = true
    @inverted_colors = false
    @dual_page_odd_left = false
    @rtl = false
    @min_scale = DEFAULT_MIN_SCALE
    @max_scale = DEFAULT_MAX_SCALE
    @annotation_editing = ANNOTATION_EDITING_STATE_NONE
    @n_pages = 0
    @annotation_model = annotation_model

    annotation_model.signal_connect('notify::tool') { update_editing_state }

    if document
      self.document = document
    end
  end

  def signal_do_page_changed(_old_page, _new_page) = nil

  def document = @document

  # Setting the document re-clamps the current page into the new document's
  # range, so a page number carried over from the previous document cannot
  # point past the end of this one.
  def document=(document)
    @document.equal?(document).then do |same|
      unless same
        @document = document
        if document.nil?
          @n_pages = 0
        else
          @n_pages = document.n_pages
        end
        self.page = clamped_page(@page)
        notify('document')
      end
    end
  end

  def page = @page

  # Ignores a page outside the document, and emits "page-changed" with the
  # page left behind and the page arrived at.
  def page=(page)
    (@page == page || page.negative? || (@document && page >= @n_pages)).then do |refuse|
      unless refuse
        @page.then do |old_page|
          @page = page
          signal_emit('page-changed', old_page, page)
          notify('page')
        end
      end
    end
  end

  # pps_document_model_set_page_by_label: the document resolves the label, and
  # a label it does not know leaves the page alone.
  def page_by_label=(page_label)
    @document.find_page_by_label(page_label).then do |page|
      unless page.nil?
        self.page = page
      end
    end
  end

  def scale = @scale

  # The lower bound is the minimum scale only in free sizing mode; the other
  # modes compute a scale of their own and must be able to go below it.
  def scale=(scale)
    scale.clamp(@sizing_mode == SIZING_FREE ? @min_scale : 0.0, @max_scale).then do |clamped|
      unless (clamped - @scale).abs < EPSILON
        @scale = clamped
        notify('scale')
      end
    end
  end

  def max_scale = @max_scale

  def max_scale=(max_scale)
    unless (max_scale - @max_scale).abs < EPSILON
      @max_scale = max_scale

      if @scale > max_scale
        self.scale = max_scale
      end

      notify('max-scale')
    end
  end

  def min_scale = @min_scale

  def min_scale=(min_scale)
    unless (min_scale - @min_scale).abs < EPSILON
      @min_scale = min_scale

      if @scale < min_scale
        self.scale = min_scale
      end

      notify('min-scale')
    end
  end

  def sizing_mode = @sizing_mode

  def sizing_mode=(mode)
    unless mode == @sizing_mode
      @sizing_mode = mode
      notify('sizing-mode')
    end
  end

  def page_layout = @page_layout

  def page_layout=(layout)
    unless layout == @page_layout
      @page_layout = layout
      notify('page-layout')
    end
  end

  def rotation = @rotation

  # Upstream normalises one full turn in either direction, not an arbitrary
  # multiple of it.
  def rotation=(rotation)
    normalize_rotation(rotation).then do |normalized|
      unless normalized == @rotation
        @rotation = normalized
        notify('rotation')
      end
    end
  end

  def inverted_colors = @inverted_colors
  def inverted_colors? = @inverted_colors

  def inverted_colors=(inverted_colors)
    unless inverted_colors == @inverted_colors
      @inverted_colors = inverted_colors
      notify('inverted-colors')
    end
  end

  def continuous = @continuous
  def continuous? = @continuous

  def continuous=(continuous)
    (continuous != false).then do |value|
      unless value == @continuous
        @continuous = value
        notify('continuous')
      end
    end
  end

  def dual_page_odd_pages_left = @dual_page_odd_left
  def dual_page_odd_pages_left? = @dual_page_odd_left

  def dual_page_odd_pages_left=(odd_left)
    (odd_left != false).then do |value|
      unless value == @dual_page_odd_left
        @dual_page_odd_left = value
        notify('dual-odd-left')
      end
    end
  end

  def rtl = @rtl
  def rtl? = @rtl

  def rtl=(rtl)
    (rtl != false).then do |value|
      unless value == @rtl
        @rtl = value
        notify('rtl')
      end
    end
  end

  def annotation_editing_state = @annotation_editing

  # Set while annotation editing widgets are shown over the page and the
  # backend is not rendering those annotations itself.
  def annotation_editing_state=(state)
    unless state == @annotation_editing
      @annotation_editing = state
      notify('annotation-editing-state')
    end
  end

  private

    # Once editing has started, switching tools switches which kind of editing
    # is in progress; with editing off, a tool change changes nothing.
    def update_editing_state
      unless @annotation_editing == ANNOTATION_EDITING_STATE_NONE
        case @annotation_model.tool
        when AnnotationModel::TOOL_TEXT
          self.annotation_editing_state =
            ANNOTATION_EDITING_STATE_INSERT_TEXT | ANNOTATION_EDITING_STATE_TEXT
        else
          self.annotation_editing_state = ANNOTATION_EDITING_STATE_INK
        end
      end
    end

    # CLAMP(page, 0, n_pages - 1) with no pages hands back -1, which set_page
    # then refuses — so an empty document leaves the page where it was.
    def clamped_page(page)
      if @n_pages.positive?
        page.clamp(0, @n_pages - 1)
      else
        -1
      end
    end

    def normalize_rotation(rotation)
      if rotation >= 360
        rotation - 360
      elsif rotation.negative?
        rotation + 360
      else
        rotation
      end
    end
end
