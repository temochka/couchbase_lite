module CouchbaseLite
  module FFI
    extend ::FFI::Library
    PATH = if RUBY_PLATFORM.include?('darwin')
             ['libLiteCore.dylib', 'macos/libLiteCore.dylib']
           else
             ['libLiteCore.so', 'unix/libLiteCore.so']
           end.freeze
    ffi_lib PATH

    class RubyObjectRef < ::FFI::Struct
      layout :object_id, :uint64

      def deref
        ObjectSpace._id2ref(self[:object_id])
      end
    end

    class FLArrayIterator < ::FFI::Struct
      layout :_private1, :pointer,
             :_private2, :uint32,
             :_private3, :bool,
             :_private4, :pointer
    end

    module C4StringLike
      def self.included(base)
        base.class_eval do
          layout :buf, :pointer,
                 :size, :size_t
        end
      end

      def to_s
        self[:buf].read_string(self[:size])
      end

      def to_bytes
        self[:buf].read_array_of_int8(self[:size])
      end
    end

    # typedef struct {
    #     const void *buf;
    #     size_t size;
    # } C4Slice;
    class C4Slice < ::FFI::Struct
      include C4StringLike

      NULL = new.tap do |s|
        s[:buf] = nil
        s[:size] = 0
      end

      def self.null
        NULL
      end

      def self.from_string(string)
        pointer = ::FFI::MemoryPointer.new(string.bytesize + 1)
        pointer.put_string(0, string)

        s = new
        s[:buf] = pointer
        s[:size] = string.bytesize
        s
      end

      def self.from_bytes(bytes)
        pointer = ::FFI::MemoryPointer.new(bytes.count)
        pointer.put_array_of_int8(0, bytes)

        s = new
        s[:buf] = pointer
        s[:size] = bytes.count
        s
      end
    end

    C4String = C4Slice

    class C4SliceResult < ::FFI::ManagedStruct
      include C4StringLike

      def self.release(ptr)
        FFI.c4slice_free(ptr)
      end

      def initialize(ptr)
        if ptr.is_a?(::FFI::MemoryPointer)
          # Opt out of auto memory management and use c4slice_free
          ptr.autorelease = false
          super(::FFI::Pointer.new(ptr))
        else
          super
        end
      end
    end

    C4StringResult = C4SliceResult

    # // (These are identical to the internal C++ error::Domain enum values.)
    # typedef C4_ENUM(uint32_t, C4ErrorDomain) {
    #     LiteCoreDomain = 1, // code is a Couchbase Lite Core error code (see below)
    #     POSIXDomain,        // code is an errno
    #                         // domain 3 is unused
    #     SQLiteDomain = 4,   // code is a SQLite error
    #     FleeceDomain,       // code is a Fleece error
    #     NetworkDomain,      // code is a network error code from the enum below
    #     WebSocketDomain,    // code is a WebSocket close code (1000...1015) or HTTP error (400..599)

    #     kC4MaxErrorDomainPlus1
    # };
    enum :C4ErrorDomain,
      [:LiteCoreDomain, 1,
       :POSIXDomain,
       :SQLiteDomain, 4,
       :FleeceDomain,
       :NetworkDomain,
       :WebSocketDomain,
       :kC4MaxErrorDomainPlus1]

    # typedef struct {
    #     C4ErrorDomain domain;
    #     int32_t code;
    #     int32_t internal_info;
    # } C4Error;
    class C4Error < ::FFI::Struct
      layout :domain, :C4ErrorDomain,
             :code, :int32,
             :internal_info, :int32

      def domain
        self[:domain]
      end

      def code
        self[:code]
      end
    end

    enum :C4EncryptionAlgorithm,
         [:kC4EncryptionNone, :kC4EncryptionAES128, :kC4EncryptionAES256]

    # typedef C4_ENUM(uint32_t, C4DocumentVersioning) {
    #     kC4RevisionTrees,           ///< Revision trees
    # };
    enum :C4DocumentVersioning, [:kC4RevisionTrees]

    # typedef struct C4EncryptionKey {
    #     C4EncryptionAlgorithm algorithm;
    #     uint8_t bytes[32];
    # } C4EncryptionKey;
    class C4EncryptionKey < ::FFI::Struct
      layout :algorithm, :C4EncryptionAlgorithm,
             :bytes, [:uint8, 32]
    end


    # /** Boolean options for C4DatabaseConfig. */
    # typedef C4_OPTIONS(uint32_t, C4DatabaseFlags) {
    #     kC4DB_Create        = 1,    ///< Create the file if it doesn't exist
    #     kC4DB_ReadOnly      = 2,    ///< Open file read-only
    #     kC4DB_AutoCompact   = 4,    ///< Enable auto-compaction
    #     kC4DB_SharedKeys    = 0x10, ///< Enable shared-keys optimization at creation time
    #     kC4DB_NoUpgrade     = 0x20, ///< Disable upgrading an older-version database
    #     kC4DB_NonObservable = 0x40, ///< Disable c4DatabaseObserver
    # };
    C4DB_Create = 0x1
    C4DB_ReadOnly = 0x2
    C4DB_AutoCompact = 0x4
    C4DB_SharedKeys = 0x10

    attach_variable :kC4SQLiteStorageEngine, :string

    # /** Main database configuration struct. */
    # typedef struct C4DatabaseConfig {
    #     C4DatabaseFlags flags;          ///< Create, ReadOnly, AutoCompact, Bundled...
    #     C4StorageEngine storageEngine;  ///< Which storage to use, or NULL for no preference
    #     C4DocumentVersioning versioning;///< Type of document versioning
    #     C4EncryptionKey encryptionKey;  ///< Encryption to use creating/opening the db
    # } C4DatabaseConfig;
    class C4DatabaseConfig < ::FFI::Struct
      layout :flags, :uint32,
             :storageEngine, :string,
             :versioning, :C4DocumentVersioning,
             :encryptionKey, C4EncryptionKey
    end

    class C4Database
      def self.auto(ptr)
        ::FFI::AutoPointer.new(ptr, FFI.method(:c4db_free))
      end
    end

    class C4BlobKey < ::FFI::Struct
      layout :bytes, [:uint8, 20]
    end

    # /** Flags describing a document. */
    # typedef C4_OPTIONS(uint32_t, C4DocumentFlags) {
    #     kDocDeleted         = 0x01,     ///< The document's current revision is deleted.
    #     kDocConflicted      = 0x02,     ///< The document is in conflict.
    #     kDocHasAttachments  = 0x04,     ///< The document's current revision has attachments.
    #     kDocExists          = 0x1000    ///< The document exists (i.e. has revisions.)
    # }; // Note: Superset of DocumentFlags
    C4DOC_DocDeleted = 0x01
    C4DOC_DocConflicted = 0x02
    C4DOC_DocHasAttachments = 0x04
    C4DOC_DocExists = 0x1000

    # /** Flags that apply to a revision. */
    #   typedef C4_OPTIONS(uint8_t, C4RevisionFlags) {
    #       kRevDeleted        = 0x01, ///< Is this revision a deletion/tombstone?
    #       kRevLeaf           = 0x02, ///< Is this revision a leaf (no children?)
    #       kRevNew            = 0x04, ///< Has this rev been inserted since the doc was read?
    #       kRevHasAttachments = 0x08, ///< Does this rev's body contain attachments?
    #       kRevKeepBody       = 0x10, ///< Revision's body should not be discarded when non-leaf
    #       kRevIsConflict     = 0x20, ///< Unresolved conflicting revision; will never be current
    #   }; // Note: Same as Revision::Flags
    C4DOC_RevDeleted = 0x01
    C4DOC_RevLeaf = 0x02
    C4DOC_RevNew = 0x04
    C4DOC_RevHasAttachments = 0x08
    C4DOC_kRevKeepBody = 0x10
    C4DOC_kRevIsConflict = 0x20


    # /** Describes a revision of a document. A sub-struct of C4Document. */
    # typedef struct {
    #     C4String revID;              ///< Revision ID
    #     C4RevisionFlags flags;      ///< Flags (deleted?, leaf?, new? hasAttachments?)
    #     C4SequenceNumber sequence;  ///< Sequence number in database
    #     C4String body;               ///< The raw body, or NULL if not loaded yet
    # } C4Revision;
    class C4Revision < ::FFI::Struct
      layout :revID, C4String,
             :flags, :uint8, # C4RevisionFlags
             :sequence, :uint64, # C4SequenceNumber
             :body, C4String
    end

    # /** Describes a version-controlled document. */
    # typedef struct C4Document {
    #     C4DocumentFlags flags;      ///< Document flags
    #     C4String docID;              ///< Document ID
    #     C4String revID;              ///< Revision ID of current revision
    #     C4SequenceNumber sequence;  ///< Sequence at which doc was last updated

    #     C4Revision selectedRev;     ///< Describes the currently-selected revision
    # } C4Document;
    class C4Document < ::FFI::ManagedStruct
      layout :flags, :uint32,
             :docID, C4String,
             :revID, C4String,
             :sequence, :uint64,
             :selectedRev, C4Revision

      def self.release(ptr)
        FFI.c4doc_free(ptr)
      end

      def id
        self[:docID]
      end

      def rev
        self[:revID]
      end

      def sequence
        self[:sequence]
      end

      def flags
        self[:flags]
      end

      def mark_for_deletion
        self[:flags] = flags | C4DOC_DocDeleted
      end

      def deleted?
        C4DOC_DocDeleted == (flags & C4DOC_DocDeleted)
      end
    end

    # /** Parameters for adding a revision using c4doc_put. */
    # typedef struct {
    #     C4String body;              ///< Revision's body
    #     C4String docID;             ///< Document ID
    #     C4RevisionFlags revFlags;   ///< Revision flags (deletion, attachments, keepBody)
    #     bool existingRevision;      ///< Is this an already-existing rev coming from replication?
    #     bool allowConflict;         ///< OK to create a conflict, i.e. can parent be non-leaf?
    #     const C4String *history;     ///< Array of ancestor revision IDs
    #     size_t historyCount;        ///< Size of history[] array
    #     bool save;                  ///< Save the document after inserting the revision?
    #     uint32_t maxRevTreeDepth;   ///< Max depth of revision tree to save (or 0 for default)
    #     C4RemoteID remoteDBID;      ///< Identifier of remote db this rev's from (or 0 if local)
    # } C4DocPutRequest;
    class C4DocPutRequest < ::FFI::Struct
      layout :body, C4String,
             :docID, C4String,
             :revFlags, :uint8,
             :existingRevision, :bool,
             :allowConflict, :bool,
             :history, :pointer,
             :historyCount, :size_t,
             :save, :bool,
             :maxRevTreeDepth, :uint32,
             :remoteDBID, :uint32
    end

    class C4Query
      def self.auto(ptr)
        ::FFI::AutoPointer.new(ptr, FFI.method(:c4query_free))
      end
    end

    # /** A query result enumerator.
    #     Created by c4db_query. Must be freed with c4queryenum_free.
    #     The fields of this struct represent the current matched index row, and are valid until the
    #     next call to c4queryenum_next or c4queryenum_free. */
    # typedef struct {
    #     /** The columns of this result, in the same order as in the query's `WHAT` clause. */
    #     FLArrayIterator columns;

    #     /** A bitmap where a 1 bit represents a column whose value is MISSING.
    #         This is how you tell a missing property value from a value that's JSON 'null',
    #         since the value in the `columns` array will be a Fleece `null` either way. */
    #     uint64_t missingColumns;

    #     /** The number of full-text matches (i.e. the number of items in `fullTextMatches`) */
    #     uint32_t fullTextMatchCount;

    #     /** Array with details of each full-text match */
    #     const C4FullTextMatch *fullTextMatches;
    # } C4QueryEnumerator;
    class C4QueryEnumerator < ::FFI::ManagedStruct
      layout :columns, FLArrayIterator,
             :missingColumns, :uint64,
             :fullTextMatchCount, :uint32,
             :fullTextMatches, :pointer

      def self.release(ptr)
        FFI.c4queryenum_free(ptr)
      end
    end

    # /** Options for running queries. */
    # typedef struct {
    #     bool rankFullText;      ///< Should full-text results be ranked by relevance?
    # } C4QueryOptions;
    class C4QueryOptions < ::FFI::Struct
      layout :rankFullText, :bool
    end

    # /** Types of indexes. */
    # typedef C4_ENUM(uint32_t, C4IndexType) {
    #     kC4ValueIndex,         ///< Regular index of property value
    #     kC4FullTextIndex,      ///< Full-text index
    #     kC4GeoIndex,           ///< Geospatial index of GeoJSON values (NOT YET IMPLEMENTED)
    # };
    enum :C4IndexType,
         [:kC4ValueIndex,
          :kC4FullTextIndex,
          :kC4GeoIndex]

    # /** Options for indexes; these each apply to specific types of indexes. */
    # typedef struct {
    #     /** Dominant language of text to be indexed; setting this enables word stemming, i.e.
    #         matching different cases of the same word ("big" and "bigger", for instance.)
    #         Can be an ISO-639 language code or a lowercase (English) language name; supported
    #         languages are: da/danish, nl/dutch, en/english, fi/finnish, fr/french, de/german,
    #         hu/hungarian, it/italian, no/norwegian, pt/portuguese, ro/romanian, ru/russian,
    #         es/spanish, sv/swedish, tr/turkish.
    #         If left null,  or set to an unrecognized language, no language-specific behaviors
    #         such as stemming and stop-word removal occur. */
    #     const char *language;

    #     /** Should diacritical marks (accents) be ignored? Defaults to false.
    #         Generally this should be left false for non-English text. */
    #     bool ignoreDiacritics;

    #     /** "Stemming" coalesces different grammatical forms of the same word ("big" and "bigger",
    #         for instance.) Full-text search normally uses stemming if the language is one for
    #         which stemming rules are available, but this flag can be set to `true` to disable it.
    #         Stemming is currently available for these languages: da/danish, nl/dutch, en/english,
    #         fi/finnish, fr/french, de/german, hu/hungarian, it/italian, no/norwegian, pt/portuguese,
    #         ro/romanian, ru/russian, s/spanish, sv/swedish, tr/turkish. */
    #     bool disableStemming;

    #     /** List of words to ignore ("stop words") for full-text search. Ignoring common words
    #         like "the" and "a" helps keep down the size of the index.
    #         If NULL, a default word list will be used based on the `language` option, if there is
    #         one for that language.
    #         To suppress stop-words, use an empty string.
    #         To provide a custom list of words, use a string containing the words in lowercase
    #         separated by spaces. */
    #     const char *stopWords;
    # } C4IndexOptions;
    class C4IndexOptions < ::FFI::Struct
      layout :language, :string,
             :ignoreDiacrticis, :bool,
             :disableStemming, :bool,
             :stopWords, :string
    end

    # /** A simple parsed-URL type */
    # typedef struct {
    #     C4String scheme;
    #     C4String hostname;
    #     uint16_t port;
    #     C4String path;
    # } C4Address;
    class C4Address < ::FFI::Struct
      def self.from_url(url)
        address = FFI::C4Address.new
        dbname = FFI::C4String.new
        FFI.c4address_fromURL(FFI::C4String.from_string(url.to_s), address, dbname)
        [address, dbname]
      end

      layout :scheme, C4String,
             :hostname, C4String,
             :port, :uint16,
             :path, C4String

      def to_s
        FFI.c4address_toURL(self).to_s
      end
    end

    # typedef C4_ENUM(int8_t, C4LogLevel) {
    #   kC4LogDebug,
    #     kC4LogVerbose,
    #     kC4LogInfo,
    #     kC4LogWarning,
    #     kC4LogError,
    #     kC4LogNone
    # };
    enum :C4LogLevel, %i(kC4LogVerbose kC4LogInfo kC4LogWarning kC4LogError kC4LogNone)

    # /** A log domain, a specific source of logs that can be enabled or disabled. */
    # typedef struct c4LogDomain *C4LogDomain;
    #
    # CBL_CORE_API extern const C4LogDomain
    #     kC4DefaultLog,                  ///< The default log domain
    #     kC4DatabaseLog,                 ///< Log domain for database operations
    #     kC4QueryLog,                    ///< Log domain for query operations
    #     kC4SyncLog,                     ///< Log domain for replication operations
    #     kC4WebSocketLog;                ///< Log domain for WebSocket operations
    attach_variable :log_domain_default, :kC4DefaultLog, :pointer
    attach_variable :log_domain_database, :kC4DatabaseLog, :pointer
    attach_variable :log_domain_query, :kC4QueryLog, :pointer
    attach_variable :log_domain_sync, :kC4SyncLog, :pointer
    attach_variable :log_domain_web_socket, :kC4WebSocketLog, :pointer

    class C4LogDomain
      DEFAULT = FFI.log_domain_default
      DATABASE = FFI.log_domain_database
      QUERY = FFI.log_domain_query
      SYNC = FFI.log_domain_sync
      WEB_SOCKET = FFI.log_domain_web_socket

      def self.all
        [DEFAULT, DATABASE, QUERY, SYNC, WEB_SOCKET]
      end
    end


    # /** Represents an open bidirectional byte stream (typically a TCP socket.)
    #     C4Socket is allocated and freed by LiteCore, but the client can associate it with a native
    #     stream/socket (like a file descriptor or a Java stream reference) by storing a value in its
    #     `nativeHandle` field. */
    # typedef struct C4Socket {
    #     void* nativeHandle;     ///< for client's use
    # } C4Socket;
    class C4Socket < ::FFI::Struct
      layout :nativeHandle, RubyObjectRef.ptr
    end

    # /** The type of message framing that should be applied to the socket's data (added to outgoing,
    #     parsed out of incoming.) */
    # typedef C4_ENUM(uint8_t, C4SocketFraming) {
    #     kC4WebSocketClientFraming,  ///< Frame as WebSocket client messages (masked)
    #     kC4NoFraming,               ///< No framing; use messages as-is
    #     kC4WebSocketServerFraming,  ///< Frame as WebSocket server messages (not masked)
    # };
    enum ::FFI::NativeType::UINT8,
         :C4SocketFraming,
         %i(kC4WebSocketClientFraming kC4NoFraming kC4WebSocketServerFraming)

    # /** A group of callbacks that define the implementation of sockets; the client must fill this
    #     out and pass it to c4socket_registerFactory() before using any socket-based API.
    #     These callbacks will be invoked on arbitrary background threads owned by LiteCore.
    #     They should return quickly, and perform the operation asynchronously without blocking.
    #
    #     The `providesWebSockets` flag indicates whether this factory provides a WebSocket
    #     implementation or just a raw TCP socket. */
    # typedef struct {
    #     /** This should be set to `true` if the socket factory acts as a stream of messages,
    #         `false` if it's a byte stream. */
    #     C4SocketFraming framing;
    #
    #     /** An arbitrary value that will be passed to the `open` callback. */
    #     void* context;
    #
    #     /** Called to open a socket to a destination address, asynchronously.
    #         @param socket  A new C4Socket instance to be opened. Its `nativeHandle` will be NULL;
    #                        the implementation of this function will probably store a native socket
    #                        reference there. This function should return immediately instead of
    #                        waiting for the connection to open. */
    #     void (*open)(C4Socket* socket C4NONNULL,
    #                  const C4Address* addr C4NONNULL,
    #                  C4Slice options,
    #                  void *context);
    #
    #     /** Called to write to the socket. If `providesWebSockets` is true, the data is a complete
    #         message, and the socket implementation is responsible for framing it;
    #         if `false`, it's just raw bytes to write to the stream, including the necessary framing.
    #         @param socket  The socket to write to.
    #         @param allocatedData  The data/message to send. As this is a `C4SliceResult`, the
    #             implementation of this function is responsible for freeing it when done. */
    #     void (*write)(C4Socket* socket C4NONNULL, C4SliceResult allocatedData);
    #
    #     /** Called to inform the socket that LiteCore has finished processing the data from a
    #         `c4socket_received()` call. This can be used for flow control.
    #         @param socket  The socket that whose incoming data was processed.
    #         @param byteCount  The number of bytes of data processed (the size of the `data`
    #             slice passed to a `c4socket_received()` call.) */
    #     void (*completedReceive)(C4Socket* socket C4NONNULL, size_t byteCount);
    #
    #     /** Called to close the socket.  This is only called if `providesWebSockets` is false, i.e.
    #         the socket operates at the byte level. Otherwise it may be left NULL.
    #         No more write calls will be made; the socket should process any remaining incoming bytes
    #         by calling `c4socket_received()`, then call `c4socket_closed()` when the socket closes.
    #         @param socket  The socket to close. */
    #     void (*close)(C4Socket* socket C4NONNULL);
    #
    #     /** Called to close the socket.  This is only called if `providesWebSockets` is true, i.e.
    #         the socket operates at the message level.  Otherwise it may be left NULL.
    #         The implementation should send a message that tells the remote peer that it's closing
    #         the connection, then wait for acknowledgement before closing.
    #         No more write calls will be made; the socket should process any remaining incoming
    #         messages by calling `c4socket_received()`, then call `c4socket_closed()` when the
    #         connection closes.
    #         @param socket  The socket to close. */
    #     void (*requestClose)(C4Socket* socket C4NONNULL, int status, C4String message);
    #
    #     /** Called to tell the client that a `C4Socket` object is being disposed/freed after it's
    #         closed. The implementation of this function can then dispose any state associated with
    #         the `nativeHandle`.
    #         Set this to NULL if you don't need the call.
    #         @param socket  The socket being disposed.  */
    #     void (*dispose)(C4Socket* socket C4NONNULL);
    # } C4SocketFactory;
    callback :on_socket_open, [C4Socket.ptr, C4Address.ptr, C4Slice.by_value, RubyObjectRef.ptr], :void
    callback :on_socket_write, [C4Socket.ptr, C4SliceResult.by_value], :void
    callback :on_socket_completed_receive, [C4Socket.ptr, :size_t], :void
    callback :on_socket_close, [C4Socket.ptr], :void
    callback :on_socket_request_close, [C4Socket.ptr, :int, C4String.by_value], :void
    callback :on_socket_dispose, [C4Socket.ptr], :void

    class C4SocketFactory < ::FFI::Struct
      layout :framing, :C4SocketFraming,
             :context, RubyObjectRef.ptr,
             :open, :on_socket_open,
             :write, :on_socket_write,
             :completedReceive, :on_socket_completed_receive,
             :close, :on_socket_close,
             :requestClose, :on_socket_request_close,
             :dispose, :on_socket_dispose
    end

    class C4Replicator
      def self.auto(ptr)
        ::FFI::AutoPointer.new(ptr, FFI.method(:c4repl_free))
      end
    end

    # /** How to replicate, in either direction */
    # typedef C4_ENUM(int32_t, C4ReplicatorMode) {
    #     kC4Disabled,        // Do not allow this direction
    #     kC4Passive,         // Allow peer to initiate this direction
    #     kC4OneShot,         // Replicate, then stop
    #     kC4Continuous       // Keep replication active until stopped by application
    # };
    enum :C4ReplicatorMode,
         %i(kC4Disabled kC4Passive kC4OneShot kC4Continuous)

    # typedef struct {
    #     C4ReplicatorMode                  push;              ///< Push mode (from db to remote/other db)
    #     C4ReplicatorMode                  pull;              ///< Pull mode (from db to remote/other db).
    #     C4Slice                           optionsDictFleece; ///< Optional Fleece-encoded dictionary of optional parameters.
    #     C4ReplicatorValidationFunction    validationFunc;    ///< Callback that can reject incoming revisions
    #     C4ReplicatorStatusChangedCallback onStatusChanged;   ///< Callback to be invoked when replicator's status changes.
    #     C4ReplicatorDocumentErrorCallback onDocumentError;   ///< Callback notifying of errors with individual documents
    #     void*                             callbackContext;   ///< Value to be passed to the callbacks.
    # } C4ReplicatorParameters;
    class C4ReplicatorParameters < ::FFI::Struct
      layout :push, :C4ReplicatorMode,
             :pull, :C4ReplicatorMode,
             :optionsDictFleece, C4Slice,
             :validationFunc, :pointer,
             :onStatusChanged, :pointer,
             :onDocumentError, :pointer,
             :callbackContext, :pointer,
             :socketFactory, C4SocketFactory.ptr
    end

    # /** The possible states of a replicator. */
    # typedef C4_ENUM(int32_t, C4ReplicatorActivityLevel) {
    #     kC4Stopped,     ///< Finished, or got a fatal error.
    #     kC4Offline,     ///< Not used by LiteCore; for use by higher-level APIs. */
    #     kC4Connecting,  ///< Connection is in progress.
    #     kC4Idle,        ///< Continuous replicator has caught up and is waiting for changes.
    #     kC4Busy         ///< Connected and actively working.
    # };
    enum :C4ReplicatorActivityLevel, %i(kC4Stopped kC4Offline kC4Connecting kC4Idle kC4Busy)

    # /** Represents the current progress of a replicator.
    #     The `units` fields should not be used directly, but divided (`unitsCompleted`/`unitsTotal`)
    #     to give a _very_ approximate progress fraction. */
    # typedef struct {
    #     uint64_t    unitsCompleted;     ///< Abstract number of work units completed so far
    #     uint64_t    unitsTotal;         ///< Total number of work units (a very rough approximation)
    #     uint64_t    documentCount;      ///< Number of documents transferred so far
    # } C4Progress;
    class C4Progress < ::FFI::Struct
      layout :unitsCompleted, :uint64,
             :unitsTotal, :uint64,
             :documentCount, :uint64
    end

    # /** Current status of replication. Passed to `C4ReplicatorStatusChangedCallback`. */
    # typedef struct {
    #   C4ReplicatorActivityLevel level;
    #   C4Progress progress;
    #   C4Error error;
    # } C4ReplicatorStatus;
    class C4ReplicatorStatus < ::FFI::Struct
      layout :level, :C4ReplicatorActivityLevel,
             :progress, C4Progress,
             :error, C4Error
    end

    attach_function :c4db_open, [C4String.by_value, C4DatabaseConfig.ptr, C4Error.ptr], :pointer
    attach_function :c4db_close, [:pointer, C4Error.ptr], :bool
    attach_function :c4db_free, [:pointer], :bool

    attach_function :c4db_beginTransaction,
                    [:pointer, # db
                     C4Error.ptr], # error
                    :bool
    attach_function :c4db_endTransaction,
                    [:pointer, # db
                     :bool, # commit
                     C4Error.ptr], # error
                     :bool

    attach_function :c4db_encodeJSON, [:pointer, C4Slice.by_value, C4Error.ptr], C4Slice.by_value

    attach_function :c4doc_bodyAsJSON, [C4Document.ptr, :bool, C4Error.ptr], C4SliceResult.by_value

    attach_function :c4doc_put, [:pointer, C4DocPutRequest.ptr, :pointer, C4Error.ptr], C4Document.ptr
    attach_function :c4doc_create,
                    [:pointer, # db
                     C4String.by_value, # docID
                     C4String.by_value, # body
                     :uint8, # revisionFlags
                     C4Error.ptr], # error
                    C4Document.ptr
    attach_function :c4doc_update,
                    [C4Document.ptr, # doc,
                     C4Slice.by_value, #revisionBody
                     :uint8, # revisionFlags
                     C4Error.ptr],
                    C4Document.ptr
    attach_function :c4doc_save,
                    [C4Document.ptr,
                     :uint32,
                     C4Error.ptr],
                    :bool
    attach_function :c4doc_get,
                    [:pointer, # database
                     C4String.by_value, # docID
                     :bool, # mustExist
                     C4Error.ptr
                    ],
                    C4Document.ptr
    attach_function :c4doc_free,
                    [C4Document.ptr],
                    :void

    # /** Changes the level of the given log domain.
    #     This setting is global to the entire process.
    #     Logging is further limited by the levels assigned to the current callback and/or binary file.
    #       For example, if you set the Foo domain's level to Verbose, and the current log callback is
    #     at level Warning while the binary file is at Verbose, then verbose Foo log messages will be
    #     written to the file but not to the callback. */
    # void c4log_setLevel(C4LogDomain c4Domain C4NONNULL, C4LogLevel level) C4API;
    attach_function :c4log_setLevel,
                    [:pointer, :C4LogLevel],
                    :void

    attach_function :flarrayiter_get_value,
                    :FLArrayIterator_GetValue,
                    [:pointer],
                    :pointer
    attach_function :flarrayiter_next,
                    :FLArrayIterator_Next,
                    [:pointer],
                    :bool
    attach_function :flvalue_to_json,
                    :FLValue_ToJSON,
                    [:pointer],
                    C4SliceResult.by_value

    attach_function :c4query_new,
                    [:pointer, # db
                     C4String.by_value, # expression
                     C4Error.ptr],
                    :pointer
    attach_function :c4query_free,
                    [:pointer], # query
                    :void
    attach_function :c4query_run,
                    [:pointer, #query
                     C4QueryOptions.ptr,
                     C4String.by_value,
                     C4Error.ptr],
                    C4QueryEnumerator.ptr
    attach_function :c4query_explain,
                    [:pointer], # query
                    C4StringResult.by_value
    attach_function :c4query_columnCount,
                    [:pointer], # query
                    :uint
    attach_function :c4queryenum_getRowCount,
                    [C4QueryEnumerator.ptr, C4Error.ptr],
                    :int64
    attach_function :c4queryenum_next,
                    [C4QueryEnumerator.ptr, C4Error.ptr],
                    :bool
    attach_function :c4queryenum_refresh,
                    [C4QueryEnumerator.ptr, C4Error.ptr],
                    C4QueryEnumerator.ptr
    attach_function :c4queryenum_free,
                    [:pointer], #enum
                    :void
    attach_function :c4error_getMessage,
                    [C4Error.by_value],
                    C4SliceResult.by_value
    attach_function :c4db_createIndex,
                    [:pointer, # database
                     C4String.by_value, # name
                     C4String.by_value, # expressionsJSON
                     :C4IndexType, # index type
                     C4IndexOptions.ptr, # index options
                     C4Error.ptr], # error
                    :bool

    # /** Creates a new replicator.
    #     @param db  The local database.
    #     @param remoteAddress  The address of the remote server (null if other db is local.)
    #     @param remoteDatabaseName  The name of the database at the remote address.
    #     @param otherLocalDB  The other local database (null if other db is remote.)
    #     @param params Replication parameters (see above.)
    #     @param err  Error, if replication can't be created.
    #     @return  The newly created replication, or NULL on error. */
    # C4Replicator* c4repl_new(C4Database* db C4NONNULL,
    #                          C4Address remoteAddress,
    #                          C4String remoteDatabaseName,
    #                          C4Database* otherLocalDB,
    #                          C4ReplicatorParameters params,
    #                          C4Error *err) C4API;
    attach_function :c4repl_new,
                    [:pointer, # db
                     C4Address.by_value, # address
                     C4String.by_value, # remoteDatabaseName
                     :pointer, # otherLocalDB
                     C4ReplicatorParameters.by_value, # params
                     C4Error.ptr], # error
                    :pointer

    # C4Replicator* c4repl_newWithSocket(C4Database* db,
    #                                C4Socket *openSocket,
    #                                C4ReplicatorParameters params,
    #                                C4Error *outError) C4API
    attach_function :c4repl_newWithSocket,
                    [:pointer, # db
                     C4Socket.ptr,
                     C4ReplicatorParameters.by_value,
                     C4Error.ptr],
                    :pointer

    # /** Returns the current state of a replicator. */
    # C4ReplicatorStatus c4repl_getStatus(C4Replicator *repl C4NONNULL) C4API;
    attach_function :c4repl_getStatus,
                    [:pointer],
                    C4ReplicatorStatus.by_value

    # /** A simple URL parser that populates a C4Address from a URL string.
    #     The fields of the address will point inside the url string.
    #     @param url  The URL to be parsed.
    #     @param address  On sucess, the fields of the struct this points to will be populated with
    #                     the address components. This that are slices will point into the
    #                     appropriate substrings of `url`.
    #     @param dbName  If non-NULL, then on success this slice will point to the last path
    #                     component of `url`; `address->path` will not include this component.
    #     @return  True on success, false on failure. */
    attach_function :c4address_fromURL,
                    [C4String.by_value,
                     C4Address.ptr,
                     C4String.ptr],
                    :bool

    # /** Converts a C4Address to a URL. */
    # C4StringResult c4address_toURL(C4Address address);
    attach_function :c4address_toURL,
                    [C4Address.by_value],
                    C4StringResult.by_value

    # /** Tells a replicator to stop. */
    # void c4repl_stop(C4Replicator* repl C4NONNULL) C4API;
    attach_function :c4repl_stop, [:pointer], :void

    # /** Frees a replicator reference. If the replicator is running it will stop. */
    # void c4repl_free(C4Replicator* repl) C4API;
    attach_function :c4repl_free, [:pointer], :void

    # /** Frees the memory of a heap-allocated slice by calling free(buf). */
    # void c4slice_free(C4SliceResult) C4API;
    attach_function :c4slice_free, [C4SliceResult.ptr], :void

    # /** One-time registration of socket callbacks. Must be called before using any socket-based
    #     API including the replicator. Do not call multiple times. */
    attach_function :c4socket_registerFactory, [C4SocketFactory.by_value], :void

    # /** Notification that a socket has received an HTTP response, with the given headers (encoded
    #     as a Fleece dictionary.) This should be called just before c4socket_opened or
    #     c4socket_closed. */
    # void c4socket_gotHTTPResponse(C4Socket *socket C4NONNULL,
    #                               int httpStatus,
    #                               C4Slice responseHeadersFleece) C4API;
    attach_function :c4socket_gotHTTPResponse, [C4Socket.ptr, :int, C4Slice.ptr], :void

    # /** Notification that a socket has opened, i.e. a C4SocketFactory.open request has completed
    #     successfully. */
    # void c4socket_opened(C4Socket *socket C4NONNULL) C4API;
    attach_function :c4socket_opened, [C4Socket.ptr], :void

    # /** Notification that a socket has finished closing, or that it disconnected, or failed to open.
    #     If this is a normal close in response to a C4SocketFactory.close request, the error
    #     parameter should have a code of 0.
    #     If it's a socket-level error, set the C4Error appropriately.
    #     If it's a WebSocket-level close (when the factory's providesWebSockets is true),
    #     set the error domain to WebSocketDomain and the code to the WebSocket status code. */
    # void c4socket_closed(C4Socket *socket C4NONNULL, C4Error errorIfAny) C4API;
    attach_function :c4socket_closed, [C4Socket.ptr, C4Error.by_value], :void

    # /** Notification that the peer has requested to close the socket using the WebSocket protocol.
    #     LiteCore will call the factory's requestClose callback in response when it's ready. */
    # void c4socket_closeRequested(C4Socket *socket C4NONNULL, int status, C4String message);
    attach_function :c4socket_closeRequested, [C4Socket.ptr, :int, C4String.by_value], :void

    # /** Notification that bytes have been written to the socket, in response to a
    #     C4SocketFactory.write request. */
    # void c4socket_completedWrite(C4Socket *socket C4NONNULL, size_t byteCount) C4API;
    attach_function :c4socket_completedWrite, [C4Socket.ptr, :size_t], :void

    # /** Notification that bytes have been read from the socket. LiteCore will acknowledge receiving
    #     and processing the data by calling C4SocketFactory.completedReceive.
    #     For flow-control purposes, the client should keep track of the number of unacknowledged
    #     bytes, and stop reading from the underlying stream if it grows too large. */
    # void c4socket_received(C4Socket *socket C4NONNULL, C4Slice data) C4API;
    attach_function :c4socket_received, [C4Socket.ptr, C4Slice.by_value], :void

    # C4Socket* c4socket_fromNative(C4SocketFactory factory,
    #                               void *nativeHandle,
    #                               const C4Address *address) C4API
    attach_function :c4socket_fromNative,
                    [C4SocketFactory.by_value, RubyObjectRef.ptr, C4Address.ptr],
                    C4Socket.ptr
  end
end
