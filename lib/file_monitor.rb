# frozen_string_literal: true

require 'gio2'

# FileMonitor watches the open document's file and says when it has changed on
# disk, so the window can offer to reload it.
#
# Ported from upstream's shell/src/file_monitor.rs. The debounce is the point
# of the class: a program writing a PDF emits a stream of "changed" events,
# and reloading on each one would reload a half-written file. So a plain
# "changed" starts (or restarts) a five second timer and only the timer firing
# reports the change, while GIO's "changes done" hint — which means the writer
# has stopped — cancels the timer and reports immediately.
#
class FileMonitor < GLib::Object
  type_register

  # Upstream's timeout_add_seconds_local_once(5, ...)
  SETTLE_SECONDS = 5

  define_signal(
    'changed',
    GLib::Signal::RUN_LAST | GLib::Signal::ACTION,
    nil,
    nil,
  )

  install_property(
    GLib::Param::String.new(
      'uri',
      'URI',
      'The URI being monitored',
      nil,
      GLib::Param::READABLE,
    ),
  )

  attr_reader :uri

  # A file that cannot be monitored at all — most network mounts — is
  # reported and then simply never reports a change, which is upstream's
  # behaviour too.
  def initialize(uri)
    super()
    @uri = uri
    @timeout_id = nil

    begin
      @monitor = Gio::File.new_for_uri(uri).monitor_file(:none)
      @monitor.signal_connect('changed') do |_monitor, _file, _other, event|
        handle(event)
      end
    rescue Gio::Error, GLib::Error => e
      warn e.message
    end
  end

  def signal_do_changed = nil

  # Called when the window closes the document, so a pending timer cannot
  # report a change against a document nobody is looking at.
  def dispose
    timeout_stop
  end

  private

    def handle(event)
      case event
      when Gio::FileMonitorEvent::CHANGES_DONE_HINT
        timeout_stop
        signal_emit('changed')
      when Gio::FileMonitorEvent::CHANGED
        timeout_start
      end
    end

    def timeout_start
      timeout_stop

      @timeout_id = GLib::Timeout.add_seconds(SETTLE_SECONDS) do
        @timeout_id = nil
        signal_emit('changed')
        GLib::Source::REMOVE
      end
    end

    def timeout_stop
      @timeout_id.then do |id|
        unless id.nil?
          GLib::Source.remove(id)
          @timeout_id = nil
        end
      end
    end
end
