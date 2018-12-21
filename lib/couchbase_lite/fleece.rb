module CouchbaseLite
  module Fleece
    extend ErrorHandling

    def self.parse(string, opts = {})
      c4_string = string.is_a?(String) ? FFI::C4String.from_string(string) : FFI::C4String.from_bytes(string)
      flvalue = FFI.flvalue_from_data(c4_string, :kFLUntrusted)
      json = FFI.flvalue_to_json(flvalue)
      JSON.parse(json.to_s, opts)
    end

    def self.dump(data)
      json = JSON.dump(data)
      c4_string = FFI::C4String.from_string(json)
      c4_slice = blank_err { |e| FFI.fldata_convert_json(c4_string, e) }
      c4_slice.to_s
    end
  end
end
