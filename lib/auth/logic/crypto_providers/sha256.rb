# frozen_string_literal: true

require "digest/sha2"

module Authentication
  module Logic
    # The acts_as_authentic method has a crypto_provider option. This allows you
    # to use any type of encryption you like. Just create a class with a class
    # level encrypt and matches? method. See example below.
    #
    # === Example
    #
    #   class MyAwesomeEncryptionMethod
    #     def self.encrypt(*tokens)
    #       # the tokens passed will be an array of objects, what type of object
    #       # is irrelevant, just do what you need to do with them and return a
    #       # single encrypted string. for example, you will most likely join all
    #       # of the objects into a single string and then encrypt that string
    #     end
    #
    #     def self.matches?(crypted, *tokens)
    #       # return true if the crypted string matches the tokens. Depending on
    #       # your algorithm you might decrypt the string then compare it to the
    #       # token, or you might encrypt the tokens and make sure it matches the
    #       # crypted string, its up to you.
    #     end
    #   end
    module CryptoProviders
      # = Sha256
      #
      # Uses the Sha256 hash algorithm to encrypt passwords.
      class Sha256
        # V2 hashes the digest bytes in repeated stretches instead of hex characters.
        autoload :V2, File.join(__dir__, "sha256", "v2")

        class << self
          attr_accessor :join_token

          # The number of times to loop through the encryption.
          def stretches
            @stretches ||= 20
          end
          attr_writer :stretches

          # Turns your raw password into a Sha256 hash.
          def encrypt(*tokens)
            digest = tokens.flatten.join(join_token)
            stretches.times { digest = Digest::SHA256.hexdigest(digest) }
            digest
          end

          # Does the crypted password match the tokens? Uses the same tokens that
          # were used to encrypt.
          def matches?(crypted, *tokens)
            encrypt(*tokens) == crypted
          end
        end
      end
    end
  end
end
