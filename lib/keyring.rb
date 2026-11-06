# frozen_string_literal: true

require 'libsecret'

# Keyring stores and retrieves a locked document's password in the user's
# secret service.
#
# Ported from upstream's shell/src/keyring.rs, which wraps the `oo7` crate's
# async Secret Service client around two calls: lookup_password(uri) and
# save_password(uri, password, flags). The Ruby port uses the libsecret gem's
# synchronous Secret.password_lookup_sync / Secret.password_store_sync
# instead, which talk to the same Secret Service over D-Bus.
#
# available? mirrors upstream's with-keyring build feature: whoever presents
# PasswordView decides from it whether the "remember this password" choice is
# worth offering at all. It is a cheap, synchronous check (a schema has no
# D-Bus traffic of its own), so there is no need to cache it.
#
module Keyring
  DOC_LABEL = 'org.gnome.Papers.Document'

  SCHEMA = Secret::Schema.new(
    DOC_LABEL,
    :none,
    {
      'type' => :string,
      'uri' => :string,
    },
  )

  class << self
    # Whether a secret service is reachable at all. PasswordView and
    # PasswordDialog use this to decide whether to show the "remember"
    # choice; without a running service there is nowhere to keep the answer.
    #
    # A lookup that finds nothing still means the service answered, so only a
    # GLib::Error (no D-Bus session, no secret service activatable) counts as
    # unavailable.
    def available?
      Secret.password_lookup_sync(SCHEMA, attributes_for('org.gnome.papers:availability-probe'))
      true
    rescue GLib::Error, Gio::Error
      false
    end

    # Looks up the password remembered for uri, or nil if none was saved (or
    # no secret service answers). Upstream filters the search results by
    # label; the schema's attributes already narrow the search to this
    # application's document passwords, so a result is always the right one.
    def lookup_password(uri)
      Secret.password_lookup_sync(SCHEMA, attributes_for(uri))
    rescue GLib::Error, Gio::Error
      nil
    end

    # Saves password for uri, unless flags says never to keep it — upstream's
    # early return for gio::PasswordSave::NEVER. Returns true on success,
    # false if the secret service could not be reached.
    def save_password(uri, password, flags)
      if flags == Gio::PasswordSave::NEVER
        true
      else
        Secret.password_store_sync(
          SCHEMA,
          attributes_for(uri),
          Secret::COLLECTION_DEFAULT,
          DOC_LABEL,
          password,
        )
      end
    rescue GLib::Error, Gio::Error
      false
    end

    private

      def attributes_for(uri) = {'type' => 'document_password', 'uri' => uri}
  end
end
