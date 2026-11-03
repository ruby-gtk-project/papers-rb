# frozen_string_literal: true

require 'json'
require 'fileutils'

# Settings holds the keys of upstream's GSettings schemas
# (data/org.gnome.Papers.gschema.xml): "org.gnome.Papers" and its two
# children, "org.gnome.Papers.Default" and "org.gnome.Papers.Previewer".
#
# Upstream reads them through GSettings, which needs the schema compiled and
# installed into a system glib-2.0/schemas directory before the app will even
# start. Demanding an install step to run from a checkout is worse than the
# alternative, so the same schemas, keys, defaults and value ranges are backed
# by one JSON file under XDG_CONFIG_HOME instead. The nesting is kept: the
# root schema's children are reached with #child, exactly as
# g_settings_get_child spells it.
#
class Settings
  # The enum org.gnome.Papers.SizingMode, in its declared order.
  SIZING_MODES = %w[fit-page fit-width free automatic].freeze

  # org.gnome.Papers — path /org/gnome/papers/
  ROOT_DEFAULTS = {
    'override-restrictions'   => true,
    'document-directory'      => nil,
    'pictures-directory'      => nil,
    'page-cache-size'         => 200,
    'allow-links-change-zoom' => false,
    'night-mode'              => false,
  }.freeze

  # org.gnome.Papers.Default — path /org/gnome/papers/default/
  DEFAULT_DEFAULTS = {
    'enable-spellchecking'        => true,
    'show-sidebar'                => true,
    'window-width'                => 1280,
    'window-height'               => 1280,
    'sizing-mode'                 => 'automatic',
    'zoom'                        => 1.0,
    'continuous'                  => true,
    'dual-page'                   => false,
    'dual-page-odd-left'          => false,
    'fullscreen'                  => false,
    'window-maximized'            => false,
    'sidebar-page'                => 'links',
    'annot-color'                 => 'yellow',
    'pen-color'                   => 'blue',
    'pen-stroke'                  => 1.0,
    'highlight-color'             => 'yellow',
    'highlight-stroke'            => 2.0,
    'eraser-radius'               => 5.0,
    'eraser-mode-objects'         => 'true',
    'text-color'                  => 'blue',
    'last-used-signature-id'      => '',
    'signature-last-placed-scale' => 0.0,
  }.freeze

  # org.gnome.Papers.Previewer — path /org/gnome/papers/previewer/
  PREVIEWER_DEFAULTS = {
    'window-height'    => 1000,
    'window-width'     => 800,
    'window-maximized' => false,
  }.freeze

  CHILD_DEFAULTS = {
    'default'   => DEFAULT_DEFAULTS,
    'previewer' => PREVIEWER_DEFAULTS,
  }.freeze

  SCHEMA_IDS = {
    'org.gnome.Papers'           => ROOT_DEFAULTS,
    'org.gnome.Papers.Default'   => DEFAULT_DEFAULTS,
    'org.gnome.Papers.Previewer' => PREVIEWER_DEFAULTS,
  }.freeze

  attr_reader :defaults, :path

  # The root schema is what callers construct; the children are reached with
  # #child and share the root's file and in-memory tree.
  def initialize(path: nil, defaults: ROOT_DEFAULTS, section: nil, store: nil)
    @path = path || default_path
    @defaults = defaults
    @section = section
    @store = store || read_store
    @children = {}
  end

  # Mirrors g_settings_get_child: the child owns the same backing store, under
  # its own section of it.
  def child(name)
    @children[name.to_s] ||= self.class.new(
      path:     @path,
      defaults: CHILD_DEFAULTS.fetch(name.to_s),
      section:  name.to_s,
      store:    @store,
    )
  end

  def default = child('default')
  def previewer = child('previewer')

  def [](key)
    values.fetch(key.to_s) { @defaults.fetch(key.to_s) }
  end

  def []=(key, value)
    @defaults.fetch(key.to_s)
    values[key.to_s] = value
    write
    value
  end

  # g_settings_reset: drop the stored value so the schema default shows again.
  def reset(key)
    values.delete(key.to_s)
    write
    self[key]
  end

  def keys = @defaults.keys

  # The sizing-mode key is the one enum-typed key in the schemas. #sizing_mode
  # answers its nick, like every other key's accessor; these two translate
  # between the nick and the position the enum declares it at, which is what a
  # DocumentModel's sizing mode is numbered by.
  def sizing_mode_index = SIZING_MODES.index(self['sizing-mode'])

  def sizing_mode_index=(index)
    self['sizing-mode'] = SIZING_MODES.fetch(index)
  end

  # Restores the window geometry recorded by the previous run. Both the
  # Default and the Previewer schema carry these keys; "fullscreen" is only in
  # the Default one, so a schema without it simply has nothing to apply.
  def apply_to(window)
    window.set_default_size(self['window-width'], self['window-height'])

    if self['window-maximized']
      window.maximize
    end

    if @defaults.key?('fullscreen') && self['fullscreen']
      window.fullscreen
    end
  end

  # Records the window geometry, skipping the size while the window fills the
  # screen so the restored size is the one the user actually chose.
  def remember(window)
    self['window-maximized'] = window.maximized?

    if @defaults.key?('fullscreen')
      self['fullscreen'] = window.fullscreen?
    end

    (window.maximized? || window.fullscreen?).then do |filling_the_screen|
      unless filling_the_screen
        values['window-width'] = window.default_width
        values['window-height'] = window.default_height
        write
      end
    end
  end

  # Named accessors for every key, so callers do not repeat the strings:
  # 'night-mode' is #night_mode, and a boolean key also gets #night_mode?.
  ALL_KEYS = (ROOT_DEFAULTS.keys + DEFAULT_DEFAULTS.keys + PREVIEWER_DEFAULTS.keys).uniq.freeze

  BOOLEAN_KEYS = SCHEMA_IDS.values.flat_map { |schema|
    schema.select { |_key, value| value == true || value == false }.keys
  }.uniq.freeze

  ALL_KEYS.each do |key|
    method_name = key.tr('-', '_')

    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }

    if BOOLEAN_KEYS.include?(key)
      define_method(:"#{method_name}?") { self[key] == true }
    end
  end

  private

    def values
      @store[@section || 'papers'] ||= {}
    end

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
        'ruby-papers',
        'settings.json',
      )
    end

    def read_store
      File.exist?(@path) ? JSON.parse(File.read(@path)) : {}
    rescue JSON::ParserError => e
      warn "Error parsing #{@path}: #{e.message}"
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(@store))
    end
end
