# frozen_string_literal: true

require 'gio2'
require 'tmpdir'

# Metadata remembers per-document state — the page last read, the zoom, the
# sidebar's width and which page of it was showing — alongside the file
# itself rather than in a database of the application's own.
#
# Ported from upstream's libview/context/pps-metadata.c. The storage is the
# same: GIO's "metadata::" file attributes, under the "metadata::papers"
# namespace, which on a local filesystem GVfs keeps in the user's own
# metadata store. Values are written as strings and read back as strings,
# ints, doubles or booleans, exactly as upstream's typed getters do.
#
class Metadata
  NAMESPACE = 'metadata::papers'
  PREFIX = "#{NAMESPACE}::"

  attr_reader :file

  # A file in the temporary directory gets no metadata: it is about to be
  # thrown away, and upstream refuses to annotate it for the same reason.
  def initialize(file)
    @items = {}
    @file = nil

    unless self.class.temp_file?(file)
      @file = file
      load
    end
  end

  # pps_file_is_temp: only a local path under the system temporary directory.
  def self.temp_file?(file)
    file.native?.then do |native|
      if native
        file.path.to_s.start_with?(Dir.tmpdir)
      else
        false
      end
    end
  end

  # Whether the file's metadata can be written at all. A filesystem with no
  # writable "metadata" namespace — a FAT stick, most network mounts — cannot
  # hold any, and upstream asks before it offers to remember anything.
  def self.file_supported?(file)
    !file.query_writable_namespaces.lookup('metadata').nil?
  rescue Gio::Error, GLib::Error
    false
  end

  def empty? = @items.empty?
  def has_key?(key) = !@items[key.to_s].nil?

  def get_string(key) = @items[key.to_s]

  def set_string(key, value)
    @items[key.to_s] = value
    store(key.to_s, value)
    true
  end

  # Upstream parses with g_ascii_strtoull and rejects a string no digits could
  # be read from, leaving the caller's value untouched.
  def get_int(key)
    get_string(key).then do |value|
      if value.to_s.match?(/\A\s*[+-]?\d/)
        Integer(value.to_s.strip, exception: false) || value.to_s.to_i
      end
    end
  end

  def set_int(key, value) = set_string(key, value.to_s)

  def get_double(key)
    get_string(key).then do |value|
      Float(value.to_s, exception: false)
    end
  end

  def set_double(key, value) = set_string(key, value.to_s)

  # Booleans are stored as the ints "1" and "0", so a value written by
  # upstream reads back the same way here.
  def get_boolean(key)
    get_int(key).then do |value|
      unless value.nil?
        !value.zero?
      end
    end
  end

  def set_boolean(key, value)
    set_string(key, value ? '1' : '0')
  end

  private

    # Reads every "metadata::papers::*" attribute the file carries. A file
    # whose info cannot be queried at all is reported and left empty, which is
    # what upstream's g_warning amounts to.
    def load
      @file.query_info('metadata::*', :none).then do |info|
        if info.has_namespace?('metadata')
          info.list_attributes('metadata').each do |attribute|
            read_attribute(info, attribute)
          end
        end
      end
    rescue Gio::Error, GLib::Error => e
      warn e.message
    end

    # Only string-typed attributes are kept: the namespace holds nothing else,
    # and upstream skips anything that is not a string.
    def read_attribute(info, attribute)
      if attribute.start_with?(PREFIX)
        info.get_attribute_type(attribute).then do |type|
          if type == Gio::FileAttributeType::STRING
            @items[attribute.delete_prefix(PREFIX)] = info.get_attribute_string(attribute)
          end
        end
      end
    end

    # Writing is asynchronous, like upstream's g_file_set_attributes_async: a
    # metadata write must never block the page the user is reading. A nil
    # value unsets the attribute.
    def store(key, value)
      unless @file.nil?
        Gio::FileInfo.new.tap do |info|
          if value.nil?
            info.set_attribute(PREFIX + key, Gio::FileAttributeType::INVALID, nil)
          else
            info.set_attribute_string(PREFIX + key, value)
          end

          write_async(info)
        end
      end
    end

    def write_async(info)
      @file.set_attributes_async(info, :none, GLib::PRIORITY_DEFAULT) do |file, result|
        begin
          file.set_attributes_finish(result)
        rescue Gio::Error, GLib::Error => e
          warn e.message
        end
      end
    end
end
