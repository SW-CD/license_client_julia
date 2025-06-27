using LicenseClient

# --- Configuration ---
# On Windows, you might need to use raw strings for paths with backslashes
const SECRET_FOLDER = raw"..."
const SECRET_PASSWORD = "123"
const ALLOW_INSECURE_TLS = true


function test_secret(secret_file_path::String, password::Union{Nothing,String}; allow_insecure_tls::Bool)
    println("Testing secret file: ", secret_file_path)
    
    # Using a try-catch block is the idiomatic way to handle errors in Julia.
    # The functions now throw LicenseClientException on failure.
    try
        # 1. Parse the secret file
        @time store = parse_secret_file(secret_file_path, password)
        println("--> Success! Parsed for Client ID: ", get_client_id(store))

        # 2. Configure TLS (optional)
        if allow_insecure_tls
            set_insecure_tls(store, true)
        end

        # 3. Authenticate
        println("\nAttempting to authenticate...")
        @time authenticate(store) # Throws on failure, no need to check return value
        println("--> Authentication successful!")
        println("    Session Token: ", get_session_token(store))
        if !isnothing(get_custom_content(store))
            println("    Custom Content: ", get_custom_content(store))
        end

        # 4. Keepalive
        println("\nSleeping for 1 second...")
        sleep(1)
        println("Sending keepalive...")
        @time keepalive(store) # Throws on failure
        println("--> Keepalive successful.")

        # 5. Release
        println("\nSending release...")
        @time release(store) # Throws on failure
        println("--> Release successful.")

    catch e
        # Catch our specific exception type
        if e isa LicenseClientException
            println(stderr, "A licensing error occurred: ", e.message)
            println(stderr, "    Details -> Status: $(status_to_string(e.status)) ($(Int(e.status)))")
        else
            # Handle other potential Julia errors
            println(stderr, "An unexpected Julia error occurred: ", e)
            rethrow() # Optionally rethrow to see a stack trace
        end
    end
end

function main()
    if ALLOW_INSECURE_TLS
        println("!!! WARNING: Allowing insecure TLS connections. !!!\n")
    end

    for file in readdir(SECRET_FOLDER; join = true)
        # We test both plain-text and encrypted files
        if endswith(file, ".json")
            password = endswith(file, ".enc.json") ? SECRET_PASSWORD : nothing
            test_secret(file, password; allow_insecure_tls = ALLOW_INSECURE_TLS)
            println('='^60)
        end
    end
end

# Run the main function
main()