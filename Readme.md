# License Client Library for Julia

A high-level, idiomatic Julia wrapper for the `lic_client` shared library. This package provides the necessary tools to securely authenticate with a license server, maintain a session, and handle licensed content from within a Julia environment.

This library acts as a safe and convenient interface to the core logic provided by the pre-compiled C-compatible shared library (e.g., from the `lic_client_rust` project).

## Features

  * **High-Level Julia API**: Abstracts away the complexities of C interoperability (`ccall`), providing a clean, Julian interface.
  * **Idiomatic Error Handling**: Uses a custom `LicenseClientException` type, allowing developers to handle licensing errors with standard `try...catch` blocks.
  * **Automatic Resource Management**: Safely manages the underlying C data handle using a Julia `finalizer`, ensuring memory is always released correctly when the object goes out of scope.
  * **Full Functionality**: Provides complete access to the core client features, including parsing secrets, authentication, keepalives, and graceful session release.
  * **Type Safety**: Wraps the opaque C pointer in a Julia `mutable struct`, preventing unsafe access.

## Prerequisites & Setup

This library is a wrapper and depends on a pre-compiled shared library.

1.  **Julia Version**: Julia 1.10 or higher is recommended.

2.  **Shared Library**: You must have a compiled version of the client shared library available.

      * On Windows: `lic_client_rust.dll` or `licclient.dll`
      * On Linux: `liblic_client_rust.so` or `liblicclient.so`
      * On macOS: `liblic_client_rust.dylib` or `liblicclient.dylib`

3.  **Locating the Shared Library**: The Julia wrapper needs to know where to find the shared library. You have two options:

      * **Environment Variable (Recommended)**: Set the `LIC_CLIENT_LIB_PATH` environment variable to the absolute path of the shared library file.
        ```bash
        # Example on Linux/macOS
        export LIC_CLIENT_LIB_PATH="/path/to/your/liblic_client_rust.so"

        # Example on Windows (Command Prompt)
        set LIC_CLIENT_LIB_PATH="C:\path\to\your\lic_client_rust.dll"
        ```
      * **Modify the Source**: You can change the `DEFAULT_LIB_NAME` constant directly in `src/LicenseClient.jl` to point to the correct path on your system.

## How to Use the Library

First, add the `LicenseClient` package to your Julia project. From the Julia REPL, enter Pkg mode (by pressing `]`) and run:

```julia
(@v1.10) pkg> add /path/to/license_client_julia
```

Here is a basic example of how to use the library in your code, demonstrating the full session lifecycle and proper error handling.

```julia
using LicenseClient

function main()
    # 1. Initialize the client from a secret file
    # The library will throw a LicenseClientException on failure.
    store = nothing
    try
        println("Attempting to parse secret file...")
        store = parse_secret_file(
            "/path/to/your/client.enc.json",
            "your-secret-password"
        )
        println("--> Success! Parsed for Client ID: ", get_client_id(store))

        # Optional: For local development with self-signed certs
        # set_insecure_tls(store, true)

        # 2. Authenticate with the server
        println("\nAttempting to authenticate...")
        authenticate(store)
        println("--> Authentication successful!")
        println("    Session Token: ", get_session_token(store))

        # 3. Send a keepalive to maintain the session
        println("\nSending keepalive...")
        sleep(2) # Wait for a moment
        keepalive(store)
        println("--> Keepalive acknowledged.")

    catch e
        if e isa LicenseClientException
            println(stderr, "A licensing error occurred: ", e.message)
            println(stderr, "    Status: $(status_to_string(e.status))")
        else
            println(stderr, "An unexpected Julia error occurred: ", e)
            rethrow() # Rethrow to see the full stack trace
        end
    finally
        # 4. Release the session on graceful shutdown
        # The finalizer handles this automatically, but explicit release is good practice.
        if !isnothing(store) && !isnothing(get_session_token(store))
            println("\nReleasing the session...")
            release(store)
            println("--> Session released.")
        end
    end
end

main()
```

## API Overview

The library exports the following key components:

  * **`ClientDataStore`**: An opaque struct that holds the handle to the underlying C data structure. You will pass this object to all other functions.
  * **`LicenseClientException`**: The custom exception type thrown on any failure. It contains a `status` code and a descriptive `message`.

### Main Functions

  * `parse_secret_file(file_path, [password])`: Parses the secret file and returns a `ClientDataStore` instance.
  * `authenticate(store)`: Performs mutual authentication.
  * `keepalive(store)`: Sends a keepalive message to maintain the session.
  * `release(store)`: Gracefully terminates the session on the server.
  * `set_insecure_tls(store, allow)`: Disables TLS certificate validation for development.

### Accessor Functions

  * `get_client_id(store)`: Returns the client's ID.
  * `get_server_url(store)`: Returns the server URL.
  * `get_session_token(store)`: Returns the session token (`nothing` if not authenticated).
  * `get_custom_content(store)`: Returns custom content from the license (`nothing` if not present).
  * `status_to_string(status)`: Converts a `Status` enum to a human-readable string.