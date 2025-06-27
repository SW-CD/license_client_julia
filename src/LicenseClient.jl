module LicenseClient

export ClientDataStore, LicenseClientException, parse_secret_file, authenticate, keepalive, release, set_insecure_tls
export get_client_id, get_server_url, get_session_token, get_custom_content, status_to_string

import Libdl

# --- Configuration ---
# const DEFAULT_LIB_NAME = raw"..."
const DEFAULT_LIB_NAME = Sys.iswindows() ? "licclient.dll" : (Sys.isapple() ? "liblicclient.dylib" : "liblicclient.so")
const liblicclient_path = get(ENV, "LIC_CLIENT_LIB_PATH", DEFAULT_LIB_NAME)

# --- C Enum Mapping ---
@enum Status::Cint begin
    LIC_SUCCESS = 0
    LIC_ERROR_GENERIC = -1
    LIC_ERROR_FILE_NOT_FOUND = -2
    LIC_ERROR_BAD_PASSWORD = -3
    LIC_ERROR_INVALID_SECRET_FILE = -4
    LIC_ERROR_NETWORK = -5
    LIC_ERROR_SIGNATURE_VERIFICATION = -7
    LIC_ERROR_NOT_AUTHENTICATED = -8
    LIC_ERROR_LICENSES_IN_USE = -9
    LIC_ERROR_JSON_PARSE = -10
    LIC_ERROR_JSON_STRUCTURE = -11
    LIC_ERROR_KEY_PARSE = -12
    LIC_ERROR_FORBIDDEN = -13
    LIC_ERROR_RATE_LIMITED = -14
    LIC_ERROR_INTERNAL_SERVER = -15
    LIC_ERROR_SERVICE_UNAVAILABLE = -16
    LIC_ERROR_UNHANDLED_RESPONSE = -17
end

# --- Custom Exception Type ---
struct LicenseClientException <: Exception
    status::Status
    message::String
end

function Base.showerror(io::IO, e::LicenseClientException)
    print(io, "LicenseClientException: $(e.message) (Status: $(status_to_string(e.status)))")
end


# --- Opaque Struct Wrapper ---
mutable struct ClientDataStore
    handle::Ptr{Cvoid}

    function ClientDataStore(handle::Ptr{Cvoid})
        if handle == C_NULL
            throw(LicenseClientException(LIC_ERROR_GENERIC, "Failed to create ClientDataStore: C library returned a null handle."))
        end
        store = new(handle)
        finalizer(free_datastore, store)
        return store
    end
end

function free_datastore(store::ClientDataStore)
    if store.handle != C_NULL
        try
            ccall(
                (:lic_client_free_datastore, liblicclient_path),
                Cvoid,
                (Ptr{Cvoid},),
                store.handle
            )
        catch e
            @error "Failed to free datastore handle during finalization." exception = (e, catch_backtrace())
        end
        store.handle = C_NULL
    end
end


# --- Public High-Level Julia API ---

function parse_secret_file(file_path::String, password::Union{String,Nothing}=nothing)
    handle_ref = Ref{Ptr{Cvoid}}(C_NULL)
    c_password = isnothing(password) ? C_NULL : password

    status_code = ccall(
        (:lic_client_parse_secret_file, liblicclient_path),
        Status, (Cstring, Cstring, Ptr{Ptr{Cvoid}}),
        file_path, c_password, handle_ref
    )

    if status_code != LIC_SUCCESS
        throw(LicenseClientException(status_code, "Failed to parse secret file '$(file_path)'."))
    end

    return ClientDataStore(handle_ref[])
end

function set_insecure_tls(store::ClientDataStore, allow::Bool)
    ccall((:lic_client_set_insecure_tls, liblicclient_path), Cvoid, (Ptr{Cvoid}, Cuchar), store.handle, allow)
end

function authenticate(store::ClientDataStore)
    status = ccall((:lic_client_authenticate, liblicclient_path), Status, (Ptr{Cvoid},), store.handle)
    if status != LIC_SUCCESS
        throw(LicenseClientException(status, "Authentication failed."))
    end
    return
end

function keepalive(store::ClientDataStore)
    status = ccall((:lic_client_keepalive, liblicclient_path), Status, (Ptr{Cvoid},), store.handle)
    if status != LIC_SUCCESS
        throw(LicenseClientException(status, "Keepalive failed."))
    end
    return
end

function release(store::ClientDataStore)
    status = ccall((:lic_client_release, liblicclient_path), Status, (Ptr{Cvoid},), store.handle)
    if status != LIC_SUCCESS
        throw(LicenseClientException(status, "Release failed."))
    end
    return
end


function status_to_string(status::Status)
    c_str = ccall((:lic_client_status_to_string, liblicclient_path), Cstring, (Status,), status)
    return unsafe_string(c_str)
end


# --- Accessor Functions ---

function get_client_id(store::ClientDataStore)
    c_str = ccall((:lic_client_get_client_id, liblicclient_path), Cstring, (Ptr{Cvoid},), store.handle)
    return c_str == C_NULL ? "" : unsafe_string(c_str)
end

function get_server_url(store::ClientDataStore)
    c_str = ccall((:lic_client_get_server_url, liblicclient_path), Cstring, (Ptr{Cvoid},), store.handle)
    return c_str == C_NULL ? "" : unsafe_string(c_str)
end

function get_session_token(store::ClientDataStore)
    c_str = ccall((:lic_client_get_session_token, liblicclient_path), Cstring, (Ptr{Cvoid},), store.handle)
    return c_str == C_NULL ? nothing : unsafe_string(c_str)
end

function get_custom_content(store::ClientDataStore)
    c_str = ccall((:lic_client_get_custom_content, liblicclient_path), Cstring, (Ptr{Cvoid},), store.handle)
    return c_str == C_NULL ? nothing : unsafe_string(c_str)
end


end # module LicenseClient