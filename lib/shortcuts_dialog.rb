# frozen_string_literal: true

require 'adwaita'

# ShortcutsDialog lists the keyboard shortcuts.
#
# Ported from upstream's shell/resources/pps-shortcuts-dialog.blp, which has no
# source file of its own: it declares an Adw.ShortcutsDialog the application
# presents directly. The nine sections, their order and their items are the
# ones that file declares.
#
# An item names either an accelerator or an action. An action-named item has
# no accelerator written down — Adwaita looks up whatever the application has
# bound to that action and shows that, so these stay right when an
# accelerator is rebound. The one item that names both is upstream's, too.
#
class ShortcutsDialog < Adwaita::ShortcutsDialog
  SECTIONS = {
    'File'              => [
      { title: 'Open Document', action: 'win.open' },
      { title: 'Open Copy of Current Document', accelerator: '<Ctrl><Shift>N' },
      { title: 'Open With…', accelerator: '<Ctrl><Shift>O' },
      { title: 'Save Copy of Current Document', accelerator: '<Ctrl>S <Ctrl><Shift>S' },
      { title: 'Print Current Document', accelerator: '<Ctrl>P' },
      { title: 'Close Current Document Window', action: 'win.close' },
    ],
    'Window'            => [
      { title: 'Fullscreen', action: 'win.fullscreen' },
      { title: 'Enter Presentation Mode', action: 'win.presentation' },
      { title: 'Side Pane', accelerator: 'F9' },
      { title: 'Caret Navigation', accelerator: 'F7' },
    ],
    'Selection'         => [
      { title: 'Copy', accelerator: '<Ctrl>C <Ctrl>Insert' },
      { title: 'Select All', accelerator: '<Ctrl>A' },
    ],
    'Zoom and Rotation' => [
      { title: 'Rotate Page 90 Degrees Counter-Clockwise', accelerator: '<Ctrl>Left' },
      { title: 'Rotate Page 90 Degrees Clockwise', accelerator: '<Ctrl>Right' },
      { title: 'Zoom In', accelerator: '<Primary>plus plus' },
      { title: 'Zoom Out', accelerator: '<Primary>minus minus' },
      { title: 'Normal Size', accelerator: '<Primary>0' },
      { title: 'Zoom In (Alternative)', accelerator: '<Primary>equal equal' },
      { title: 'Fit Page', accelerator: 'f' },
      { title: 'Fit Width', accelerator: 'w' },
      { title: 'Automatic Zoom', accelerator: 'a' },
    ],
    'Navigation'        => [
      { title: 'Move Around Page', accelerator: 'Left Up Down Right' },
      { title: 'Move Up/Down Page Several Lines', accelerator: 'Page_Up Page_Down' },
      { title: 'Previous Page', accelerator: 'p <Ctrl>Page_Up' },
      { title: 'Next Page', accelerator: 'n <Ctrl>Page_Down' },
      { title: 'Go to Page Number', accelerator: '<Ctrl>L' },
      { title: 'Previous Page (Fast)', accelerator: '<Shift>Page_Up' },
      { title: 'Next Page (Fast)', accelerator: '<Shift>Page_Down' },
      { title: 'Previous Visited Page', accelerator: '<alt>P Back' },
      { title: 'Next Visited Page', accelerator: '<alt>N Forward' },
      { title: 'Go to Page Beginning/End', accelerator: 'Home End' },
      { title: 'Go to Document Start', accelerator: '<Primary>Home' },
      { title: 'Go to Document End', accelerator: '<Primary>End' },
    ],
    'Document View'     => [
      { title: 'Add Bookmark', accelerator: '<Ctrl>d' },
      { title: 'Remove Bookmark', accelerator: '<Ctrl><Shift>d' },
      { title: 'Night Mode', action: 'win.night-mode' },
      { title: 'Continuous Scrolling', accelerator: 'c' },
      { title: 'Dual Page', accelerator: 'd' },
      { title: 'Odd Pages Left', accelerator: 'o' },
      { title: 'Document Properties', accelerator: '<Alt>Return' },
      { title: 'Add Text Annotation', accelerator: 'S' },
      { title: 'Highlight Text', accelerator: 'h' },
      { title: 'Strikethrough Text', accelerator: 'k' },
      { title: 'Wavy/Squiggly Underline Text', accelerator: 'q' },
      { title: 'Underline Text', accelerator: 'u' },
      {
        title:       'Digital Signing',
        accelerator: '<Ctrl><Alt>s',
        action:      'doc.digital-signing',
      },
    ],
    'Search'            => [
      { title: 'Find', accelerator: '<Primary>F slash' },
      { title: 'Find Next', accelerator: '<Ctrl>G F3' },
      { title: 'Find Previous', accelerator: '<Ctrl><Shift>G <Shift>F3' },
    ],
    'General'           => [
      { title: 'Help', action: 'app.help' },
      { title: 'Menu', accelerator: 'F10' },
      { title: 'Keyboard Shortcuts', action: 'app.shortcuts' },
      { title: 'New Window', action: 'app.new' },
      { title: 'Close Window', action: 'win.close' },
    ],
    'Presentation Mode' => [
      { title: 'Black Screen', accelerator: 'b period' },
      { title: 'White Screen', accelerator: 'w' },
    ],
  }.freeze

  def initialize
    super()
    self.title = 'Keyboard Shortcuts'
  end

  def build
    tap do |dialog|
      SECTIONS.each do |title, items|
        dialog.add(section(title, items))
      end
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        items.each { |spec| section.add(item(spec)) }
      end
    end

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8, accelerator: utf8".
    # An action-named item is created with an empty accelerator and then told
    # its action, which is how Adwaita looks the accelerator up for itself.
    def item(spec)
      Adwaita::ShortcutsItem.new(spec[:title], spec[:accelerator].to_s).tap do |shortcut|
        unless spec[:action].nil?
          shortcut.action_name = spec[:action]
        end
      end
    end
end
