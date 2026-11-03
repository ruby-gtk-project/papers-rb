# frozen_string_literal: true

require 'adwaita'
require 'cgi'

# ProgressMessageArea is the bar the window puts above the document while a
# long job runs: an icon, a bold heading, a smaller line under it, and a
# progress bar with its own status line.
#
# Ported from upstream's shell/src/progress_message_area.rs and
# shell/resources/pps-progress-message-area.blp. The window uses it for saving
# a copy of a document and for printing one, and adds its own buttons to the
# info bar with #add_button.
#
# The markup each setter wraps its text in — bold for the heading, small for
# the secondary line — is upstream's, and it is why the labels are markup
# labels.
#
class ProgressMessageArea < Adwaita::Bin
  type_register

  install_property(
    GLib::Param::String.new(
      'text',
      'Text',
      'The heading',
      '',
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::String.new(
      'secondary-text',
      'Secondary Text',
      'The line below the heading',
      '',
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::String.new(
      'status',
      'Status',
      "The progress bar's status line",
      '',
      GLib::Param::READWRITE,
    ),
  )

  install_property(
    GLib::Param::Double.new(
      'fraction',
      'Fraction',
      'How much of the job is done',
      0.0,
      1.0,
      0.0,
      GLib::Param::READWRITE,
    ),
  )

  attr_reader :text, :secondary_text, :status, :fraction

  def initialize(icon_name = nil, text = '')
    super()
    @text = ''
    @secondary_text = ''
    @status = ''
    @fraction = 0.0
    @icon_name = icon_name
    @initial_text = text
  end

  def build
    tap do |area|
      area.child = info_bar

      info_bar.tap do |bar|
        bar.add_child(content_box)

        content_box.tap do |box|
          box.append(message_box)
          box.append(progress_box)

          message_box.tap do |message|
            message.append(image)
            message.append(labels_box)

            labels_box.tap do |labels|
              labels.append(label)
              labels.append(secondary_label)
            end
          end

          progress_box.tap do |progress|
            progress.append(progress_label)
            progress.append(progress_bar)
          end
        end
      end

      area.image_from_icon_name = @icon_name
      area.text = @initial_text
    end
  end

  def text=(text)
    markup(text, '<b>%s</b>').tap do |value|
      label.markup = value
      @text = value
      notify('text')
    end
  end

  # Upstream shows the secondary label whenever its text is set, even when the
  # text set is empty.
  def secondary_text=(text)
    markup(text, '<small>%s</small>').tap do |value|
      secondary_label.markup = value
      secondary_label.visible = true
      @secondary_text = value
      notify('secondary-text')
    end
  end

  def status=(status)
    progress_label.text = status
    @status = status
    notify('status')
  end

  def fraction=(fraction)
    progress_bar.fraction = fraction
    @fraction = fraction
    notify('fraction')
  end

  def image_from_icon_name=(icon_name)
    image.icon_name = icon_name
  end

  # The window adds its own responses — "Cancel" while saving, for one.
  def add_button(button_text, response_id)
    info_bar.add_button(button_text, response_id)
  end

  def info_bar
    @info_bar ||= Gtk::InfoBar.new.tap do |bar|
      bar.show_close_button = true
      bar.message_type = :other
    end
  end

  def content_box = @content_box ||= Gtk::Box.new(:vertical, 12)
  def message_box = @message_box ||= Gtk::Box.new(:horizontal, 12)

  def labels_box
    @labels_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.hexpand = true
      box.vexpand = false
      box.halign = :fill
    end
  end

  def progress_box = @progress_box ||= Gtk::Box.new(:vertical, 6)

  def image
    @image ||= Gtk::Image.new.tap do |widget|
      widget.pixel_size = 48
      widget.margin_top = 6
      widget.margin_bottom = 6
      widget.margin_start = 6
      widget.margin_end = 6
    end
  end

  def label
    @label ||= Gtk::Label.new.tap do |widget|
      widget.use_markup = true
      widget.wrap = true
      widget.selectable = true
      widget.xalign = 0.0
      widget.yalign = 0.5
      widget.can_focus = true
      widget.vexpand = true
    end
  end

  def secondary_label
    @secondary_label ||= Gtk::Label.new.tap do |widget|
      widget.use_markup = true
      widget.wrap = true
      widget.selectable = true
      widget.xalign = 0.0
      widget.yalign = 0.5
      widget.can_focus = true
      widget.visible = false
    end
  end

  def progress_label
    @progress_label ||= Gtk::Label.new.tap do |widget|
      widget.use_markup = true
      widget.ellipsize = :end
      widget.xalign = 0.0
      widget.yalign = 0.5
      widget.valign = :fill
      widget.vexpand = false
    end
  end

  def progress_bar
    @progress_bar ||= Gtk::ProgressBar.new.tap do |bar|
      bar.width_request = -1
      bar.height_request = 15
      bar.vexpand = false
    end
  end

  private

    # Empty text stays empty rather than becoming an empty pair of tags, and
    # anything else is escaped before the tags go round it — a document's own
    # name reaches here, and must not be read as markup.
    def markup(text, template)
      text.to_s.empty?.then do |empty|
        if empty
          ''
        else
          format(template, CGI.escapeHTML(text.to_s))
        end
      end
    end
end
