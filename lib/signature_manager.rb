# frozen_string_literal: true

require 'adwaita'
require 'gio2'
require 'gdk_pixbuf2'
require 'json'
require 'time'

# SignatureManager stores the signature images a person has drawn or
# uploaded, so any document's sign-manually flow can offer them again later.
# Each signature is a PNG file plus a JSON metadata record (id, name,
# filename, creation date, size); everything lives under the user's data
# directory, outside any document, so a signature survives closing the
# document it was first used on.
#
# Ported from upstream's shell/src/signature_manager.rs. Upstream's metadata
# round-trips through serde and a `tokio`-flavoured async file API; this port
# keeps the same metadata.json shape (so a signatures directory written by
# one is readable by the other) and the same soft-delete flow — marking a
# signature for deletion before a permanent delete actually removes it — but
# reads and writes it with Gio::File's synchronous calls, matching the rest
# of this port's GIO-backed classes (see file_monitor.rb). Upstream's
# pending_saves counter exists to tell its own writes apart from a change
# made by something else; this port keeps it for the same reason, now against
# GIO's synchronous "changed"/"changes-done-hint" events instead of an async
# future's completion.
#
class SignatureManager < GLib::Object
  type_register

  METADATA_VERSION = 1

  define_signal('signatures_list_changed', GLib::Signal::RUN_LAST, nil, nil)

  def initialize
    super()
    @metadata = nil
    @pending_saves = 0
    @pixbuf_cache = {}

    Gio::File.new_for_path(self.class.signatures_dir).make_directory_with_parents
  rescue Gio::Error, GLib::Error => e
    warn "Failed to create signatures directory: #{e.message}"
  ensure
    watch_metadata_file
  end

  def signal_do_signatures_list_changed = nil

  # The signatures currently visible to the rest of the app: anything not
  # marked for deletion.
  def list_signatures
    ensure_metadata_loaded
    @metadata['signatures'].reject { |signature| signature['pending_deletion'] }
  end

  def get_signature(id)
    ensure_metadata_loaded
    @metadata['signatures'].find { |signature| signature['id'] == id }
  end

  # Saves pixbuf as a new signature named name, and returns its id.
  def add_signature(name, pixbuf)
    ensure_metadata_loaded

    id = self.class.generate_id
    write_pixbuf(id, pixbuf)

    @metadata['signatures'].push(make_entry(id, name, pixbuf))
    save_metadata
    signal_emit('signatures_list_changed')

    id
  end

  # Replaces an existing signature's name and image in place, keeping its id.
  def update_signature(id, name, pixbuf)
    ensure_metadata_loaded

    get_signature(id).then do |signature|
      raise(GLib::Error.new(Gio::IOErrorEnum::NOT_FOUND, 'Signature not found')) if signature.nil?

      signature['name'] = name
      signature['width'] = pixbuf.width
      signature['height'] = pixbuf.height
    end

    write_pixbuf(id, pixbuf)
    @pixbuf_cache.delete(id)
    save_metadata
    signal_emit('signatures_list_changed')
  end

  # Soft-deletes: the signature stops appearing in list_signatures but its
  # file and metadata entry stay put until permanently_delete removes them.
  def mark_for_deletion(id)
    ensure_metadata_loaded

    get_signature(id).then do |signature|
      raise(GLib::Error.new(Gio::IOErrorEnum::NOT_FOUND, 'Signature not found')) if signature.nil?

      signature['pending_deletion'] = true
      signature['deletion_time'] = self.class.current_timestamp
    end

    save_metadata
    signal_emit('signatures_list_changed')
  end

  def restore_from_deletion(id)
    ensure_metadata_loaded

    get_signature(id).then do |signature|
      raise(GLib::Error.new(Gio::IOErrorEnum::NOT_FOUND, 'Signature not found')) if signature.nil?

      signature['pending_deletion'] = nil
      signature['deletion_time'] = nil
    end

    save_metadata
    signal_emit('signatures_list_changed')
  end

  def permanently_delete(id)
    ensure_metadata_loaded

    raise(GLib::Error.new(Gio::IOErrorEnum::NOT_FOUND, 'Signature not found')) if get_signature(id).nil?

    begin
      Gio::File.new_for_path(self.class.signature_path_for_id(id)).delete
    rescue GLib::Error => e
      raise(e) unless e.code == Gio::IOErrorEnum::NOT_FOUND
    end

    @pixbuf_cache.delete(id)
    @metadata['signatures'].reject! { |signature| signature['id'] == id }
    save_metadata
    signal_emit('signatures_list_changed')
  end

  def get_signature_path(id)
    ensure_metadata_loaded
    get_signature(id).then { |signature| self.class.signature_path_for_id(id) unless signature.nil? }
  end

  # Loads a signature's image from disk, keeping it around so a second call
  # for the same id does not re-read the file.
  def get_signature_pixbuf(id)
    @pixbuf_cache[id] ||= GdkPixbuf::Pixbuf.new(file: self.class.signature_path_for_id(id))
  rescue GLib::Error => e
    warn "Failed to load signature pixbuf #{id}: #{e.message}"
    nil
  end

  class << self
    def signatures_dir = File.join(GLib.user_data_dir, 'papers', 'signatures')

    def metadata_path = File.join(signatures_dir, 'metadata.json')

    def signature_path_for_id(id) = File.join(signatures_dir, "signature_#{id}.png")

    def generate_id = "sig_#{Time.now.to_i}"

    def current_timestamp = Time.now.utc.iso8601
  end

  private

    # Loads metadata.json into @metadata, unless it is already cached. A
    # missing file means a fresh signatures directory, so one is written.
    #
    # Checks the file's existence with #query_exists rather than catching
    # the NOT_FOUND error #load_contents would raise for a missing file:
    # the gio2 binding frees the GError twice while turning that particular
    # failure into a Ruby exception, which corrupts the heap and crashes the
    # process (reproduced outside this class, against a bare Gio::File).
    def ensure_metadata_loaded
      @metadata.nil?.then do |needs_load|
        if needs_load
          file = Gio::File.new_for_path(self.class.metadata_path)
          @metadata =
            if file.query_exists
              data, = file.load_contents
              JSON.parse(data)
            else
              default_metadata.tap { |metadata| write_metadata(metadata) }
            end
        end
      end
    end

    def default_metadata = {'version' => METADATA_VERSION, 'signatures' => []}

    def save_metadata
      @pending_saves += 1
      write_metadata(@metadata)
    rescue GLib::Error, Gio::Error => e
      @pending_saves -= 1 if @pending_saves.positive?
      raise(e)
    end

    def write_metadata(metadata)
      Gio::File.new_for_path(self.class.metadata_path).replace_contents(
        JSON.pretty_generate(metadata),
        nil,
        false,
        Gio::FileCreateFlags::REPLACE_DESTINATION,
      )
    end

    def write_pixbuf(id, pixbuf)
      Gio::File.new_for_path(self.class.signature_path_for_id(id)).replace_contents(
        pixbuf.save('png'),
        nil,
        false,
        Gio::FileCreateFlags::REPLACE_DESTINATION,
      )
    end

    def make_entry(id, name, pixbuf)
      {
        'id' => id,
        'name' => name,
        'filename' => "signature_#{id}.png",
        'creation_date' => self.class.current_timestamp,
        'width' => pixbuf.width,
        'height' => pixbuf.height,
        'pending_deletion' => nil,
        'deletion_time' => nil,
      }
    end

    # Watches metadata.json so a change made outside this instance (another
    # window, a manual edit) invalidates the cache. pending_saves tells this
    # instance's own writes apart from an external one: GIO reports a
    # "changes-done-hint" after replace_contents the same as after any other
    # writer, so without the counter every save would look like an external
    # change and immediately re-read the file it just wrote.
    def watch_metadata_file
      @file_monitor = Gio::File.new_for_path(self.class.metadata_path).monitor_file(:none)
      @file_monitor.signal_connect('changed') do |_monitor, _file, _other, event|
        handle_metadata_file_event(event)
      end
    rescue Gio::Error, GLib::Error => e
      warn "Failed to monitor metadata file: #{e.message}"
    end

    def handle_metadata_file_event(event)
      case event
      when Gio::FileMonitorEvent::CREATED, Gio::FileMonitorEvent::CHANGED
        external_metadata_change unless @pending_saves.positive?
      when Gio::FileMonitorEvent::CHANGES_DONE_HINT
        if @pending_saves.positive?
          @pending_saves -= 1
        else
          external_metadata_change
        end
      end
    end

    def external_metadata_change
      @metadata = nil
      signal_emit('signatures_list_changed')
    end
end
