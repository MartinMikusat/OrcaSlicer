# Network Printing Integrations

## Overview

OrcaSlicer implements a comprehensive network printing system supporting multiple protocols and cloud services. The architecture is built around a modular PrintHost abstraction that enables communication with various printer types, from traditional HTTP-based systems to modern MQTT and WebSocket implementations.

## Network Architecture

### Core Components
Implementation: `src/slic3r/Utils/`

```cpp
// Base print host interface
class PrintHost {
public:
    virtual ~PrintHost() = default;
    
    // Core operations
    virtual const char* get_name() const = 0;
    virtual bool test(wxString &curl_msg) const = 0;
    virtual wxString get_test_ok_msg() const = 0;
    virtual wxString get_test_failed_msg(wxString &msg) const = 0;
    virtual bool upload(PrintHostUpload upload_data, ProgressFn prorgess_fn, 
                       ErrorFn error_fn, InfoFn info_fn) const = 0;
    virtual bool get_storage(wxArrayString& storage_path, wxArrayString& storage_name) const;
    virtual bool has_auto_discovery() const = 0;
    virtual bool can_test() const = 0;
    virtual PrintHostPostUploadActions get_post_upload_actions() const = 0;
    virtual std::string get_host() const = 0;
    
protected:
    // Configuration
    std::string m_host;
    std::string m_apikey;
    std::string m_cafile;
    std::string m_username;
    std::string m_password;
    bool m_ssl_revoke_best_effort;
    
    // Utility methods
    std::string make_url(const std::string &path) const;
    void set_auth(Http &http) const;
    std::string timestamp_str() const;
    bool validate_version_text(const wxString &version_text) const;
};

// Upload data structure
struct PrintHostUpload {
    boost::filesystem::path source_path;    // Local file path
    boost::filesystem::path upload_path;    // Remote file path
    std::string group;                      // File group/category
    std::string storage;                    // Storage location
    PrintHostPostUploadAction post_action; // Action after upload
    std::map<std::string, std::string> extended_info; // Additional metadata
    
    PrintHostUpload(boost::filesystem::path source_path)
        : source_path(std::move(source_path)), post_action(PrintHostPostUploadAction::None) {}
};

// Post-upload actions
enum class PrintHostPostUploadAction {
    None,
    StartPrint,
    StartSimulation
};
```

### HTTP Client Foundation
Implementation: `src/slic3r/Utils/Http.cpp`

```cpp
class Http {
public:
    struct Progress {
        size_t dltotal, dlnow, ultotal, ulnow;
        Progress(size_t dltotal, size_t dlnow, size_t ultotal, size_t ulnow)
            : dltotal(dltotal), dlnow(dlnow), ultotal(ultotal), ulnow(ulnow) {}
    };
    
    using ProgressFn = std::function<bool(const Progress&, bool& cancel)>;
    using CompleteFn = std::function<void(std::string body, unsigned int status)>;
    using ErrorFn = std::function<void(std::string body, std::string error, unsigned int status)>;
    using HeaderCallbackFn = std::function<void(std::string header)>;
    
    // Configuration
    Http& size_limit(size_t sizeLimit);
    Http& header(std::string name, const std::string &value);
    Http& remove_header(std::string name);
    Http& ca_file(const std::string &filename);
    Http& form_add(const std::string &name, const std::string &contents);
    Http& form_add_file(const std::string &name, const boost::filesystem::path &path);
    Http& set_post_body(const std::string &body);
    Http& auth_digest(const std::string &user, const std::string &password);
    Http& auth_bearer(const std::string &token);
    
    // Execution
    Http& on_complete(CompleteFn fn);
    Http& on_error(ErrorFn fn);
    Http& on_progress(ProgressFn fn);
    Http& on_header(HeaderCallbackFn fn);
    void perform();
    void perform_sync();
    void cancel();
    
    // HTTP methods
    static Http get(std::string url);
    static Http post(std::string url);
    static Http put(std::string url);
    static Http patch(std::string url);
    static Http delete_(std::string url);
    
private:
    struct priv;
    std::unique_ptr<priv> p;
};
```

## Print Host Implementations

### OctoPrint Integration
Implementation: `src/slic3r/Utils/OctoPrint.cpp`

```cpp
class OctoPrint : public PrintHost {
public:
    OctoPrint(DynamicPrintConfig *config);
    ~OctoPrint() override = default;
    
    // PrintHost interface
    const char* get_name() const override;
    bool test(wxString &curl_msg) const override;
    wxString get_test_ok_msg() const override;
    wxString get_test_failed_msg(wxString &msg) const override;
    bool upload(PrintHostUpload upload_data, ProgressFn prorgess_fn, 
               ErrorFn error_fn, InfoFn info_fn) const override;
    bool has_auto_discovery() const override { return true; }
    bool can_test() const override { return true; }
    PrintHostPostUploadActions get_post_upload_actions() const override;
    
private:
    std::string m_host;
    std::string m_apikey;
    std::string m_cafile;
    bool m_ssl_revoke_best_effort;
    
    // API endpoints
    std::string make_url(const std::string &path) const;
    void set_auth(Http &http) const;
    bool validate_version_text(const wxString &version_text) const;
    
    // Version checking
    static bool version_check(const std::string &version_text);
    static std::pair<std::string, std::string> parse_version_text(const wxString &version_text);
};

// OctoPrint API implementation
bool OctoPrint::upload(PrintHostUpload upload_data, ProgressFn prorgess_fn, 
                      ErrorFn error_fn, InfoFn info_fn) const {
    
    const auto upload_filename = upload_data.upload_path.filename();
    const auto upload_parent_path = upload_data.upload_path.parent_path();
    
    Http http = Http::post(make_url("api/files/local"));
    set_auth(http);
    http.form_add("print", upload_data.post_action == PrintHostPostUploadAction::StartPrint ? "true" : "false")
        .form_add("path", upload_parent_path.string())    // path = name of folder
        .form_add_file("file", upload_data.source_path, upload_filename.string())
        .on_complete([=](std::string body, unsigned) {
            info_fn(L("File uploaded successfully"));
        })
        .on_error([=](std::string body, std::string error, unsigned status) {
            error_fn(format_error(body, error, status));
        })
        .on_progress([=](const Http::Progress& progress, bool& cancel) {
            if (prorgess_fn) {
                return prorgess_fn(progress.ultotal, progress.ulnow, cancel);
            }
            return true;
        });
    
    http.perform();
    return true;
}
```

### Bambu Lab Cloud Integration
Implementation: `src/slic3r/Utils/NetworkAgent.cpp`

```cpp
class NetworkAgent {
public:
    enum ConnectStatus {
        ConnectStatusOk = 0,
        ConnectStatusFailed = 1,
        ConnectStatusLost = 2,
    };
    
    // Core networking
    NetworkAgent();
    ~NetworkAgent();
    
    // Connection management
    int start();
    int set_config(AppConfig* config);
    std::string build_login_cmd();
    std::string build_logout_cmd();
    int connect_server();
    int disconnect_server();
    
    // User management
    int user_login(std::string name, std::string pswd);
    int user_logout();
    int bind_machine(std::string dev_id, std::string dev_ip, bool improved = true);
    int unbind_machine(std::string dev_id);
    
    // Device operations
    int start_discovery(bool start = true, int timeout = 3);
    int start_print(std::string dev_id, std::string task_id, 
                   std::string filename, std::string md5, int plate_index,
                   bool task_bed_leveling = true, bool task_flow_cali = false,
                   bool task_vibration_cali = false, bool task_layer_inspect = false,
                   bool task_first_layer_inspect = false);
    int request_setting_id(std::string dev_id, std::string setting_id);
    
    // File operations
    int start_local_print_with_record(std::string dev_id, std::string filename, 
                                     std::string filament_mapping, int plate_index,
                                     bool bed_leveling_flag, bool flow_cali_flag, 
                                     bool vibration_cali_flag, bool layer_inspect_flag,
                                     bool first_layer_inspect_flag);
    
    // Messaging
    int send_message(std::string dev_id, std::string json_str, int qos = 0);
    int set_on_ssdp_msg_fn(OnSSDPMsgFn fn);
    int set_on_user_login_fn(OnUserLoginFn fn);
    int set_on_printer_connected_fn(OnPrinterConnectedFn fn);
    int set_on_server_connected_fn(OnServerConnectedFn fn);
    int set_on_message_fn(OnMessageFn fn);
    
private:
    // MQTT integration
    class MQTTClient;
    std::unique_ptr<MQTTClient> m_mqtt_client;
    
    // Discovery
    class SSDPDiscovery;
    std::unique_ptr<SSDPDiscovery> m_ssdp_discovery;
    
    // Configuration
    AppConfig* m_config;
    std::string m_user_id;
    std::string m_user_name;
    std::string m_access_token;
    
    // Event callbacks
    OnSSDPMsgFn m_on_ssdp_msg_fn;
    OnUserLoginFn m_on_user_login_fn;
    OnPrinterConnectedFn m_on_printer_connected_fn;
    OnServerConnectedFn m_on_server_connected_fn;
    OnMessageFn m_on_message_fn;
};

// MQTT message structure
struct MQTTMessage {
    std::string topic;
    std::string payload;
    int qos;
    bool retain;
    std::chrono::system_clock::time_point timestamp;
};
```

### Cloud Service Integrations

#### Obico (The Spaghetti Detective)
Implementation: `src/slic3r/Utils/Obico.cpp`

```cpp
class Obico : public PrintHost {
public:
    Obico(DynamicPrintConfig *config);
    ~Obico() override = default;
    
    // OAuth2 authentication
    bool get_oauth2_url(wxString &url, wxString &verification_url, 
                       wxString &user_verification_url) const;
    bool get_oauth2_token(wxString &token) const;
    
    // Printer management
    bool get_printers(wxArrayString& printers) const;
    
    // PrintHost interface
    const char* get_name() const override { return "Obico"; }
    bool test(wxString &curl_msg) const override;
    bool upload(PrintHostUpload upload_data, ProgressFn prorgess_fn, 
               ErrorFn error_fn, InfoFn info_fn) const override;
    
private:
    std::string m_host;
    std::string m_access_token;
    std::string m_printer_id;
    
    // OAuth2 state
    std::string m_device_code;
    std::string m_user_code;
    std::string m_verification_uri;
    std::string m_verification_uri_complete;
    int m_expires_in;
    int m_interval;
    
    // API helpers
    std::string get_auth_header() const;
    bool validate_printer_id() const;
    std::string format_error(const std::string &body, const std::string &error, 
                            unsigned status) const;
};
```

#### SimplyPrint Integration
Implementation: `src/slic3r/Utils/SimplyPrint.cpp`

```cpp
class SimplyPrint : public PrintHost {
public:
    SimplyPrint(DynamicPrintConfig *config);
    ~SimplyPrint() override = default;
    
    // Token management
    bool refresh_token(std::string &token, std::string &refresh_token_out) const;
    
    // Chunked upload support
    bool upload_chunked(PrintHostUpload upload_data, ProgressFn prorgess_fn, 
                       ErrorFn error_fn, InfoFn info_fn) const;
    
    // PrintHost interface
    const char* get_name() const override { return "SimplyPrint"; }
    bool upload(PrintHostUpload upload_data, ProgressFn prorgess_fn, 
               ErrorFn error_fn, InfoFn info_fn) const override;
    
private:
    std::string m_host;
    std::string m_token;
    std::string m_printer_id;
    
    // Chunked upload parameters
    static const size_t CHUNK_SIZE = 1024 * 1024; // 1MB chunks
    static const int MAX_RETRIES = 3;
    
    // Upload helpers
    bool create_upload_session(const std::string &filename, size_t file_size,
                              std::string &upload_id) const;
    bool upload_chunk(const std::string &upload_id, size_t chunk_number,
                     const std::string &chunk_data) const;
    bool finalize_upload(const std::string &upload_id) const;
};
```

## Device Discovery and Management

### Bonjour/mDNS Discovery
Implementation: `src/slic3r/Utils/Bonjour.cpp`

```cpp
class Bonjour {
public:
    using TxtKeys = std::set<std::string>;
    using ReplyFn = std::function<void(BonjourReply &&reply)>;
    
    struct BonjourReply {
        std::string service_name;
        std::string hostname;
        std::string ip;
        uint16_t port;
        std::map<std::string, std::string> txt;
        
        BonjourReply(std::string service_name, std::string hostname, 
                    asio::ip::address ip, uint16_t port);
    };
    
    // Construction
    Bonjour(std::string service);
    Bonjour(Bonjour &&other);
    ~Bonjour();
    
    // Configuration
    Bonjour& set_timeout(unsigned timeout);
    Bonjour& set_retries(unsigned retries);
    Bonjour& set_txt_keys(TxtKeys txt_keys);
    Bonjour& on_reply(ReplyFn fn);
    Bonjour& on_complete(std::function<void()> fn);
    
    // Discovery
    typedef std::shared_ptr<Bonjour> Ptr;
    Ptr lookup();
    
private:
    struct priv;
    std::unique_ptr<priv> p;
};

// mDNS implementation details
struct Bonjour::priv {
    std::string service;
    std::string service_dn;
    unsigned timeout;
    unsigned retries;
    TxtKeys txt_keys;
    ReplyFn replyfn;
    std::function<void()> completefn;
    
    std::unique_ptr<asio::io_service> io_service;
    std::unique_ptr<asio::ip::udp::socket> socket;
    std::unique_ptr<asio::deadline_timer> timer;
    std::vector<char> buffer;
    asio::ip::udp::endpoint recv_endpoint;
    
    // DNS packet parsing
    void udp_receive();
    void on_receive(const boost::system::error_code &error, size_t bytes);
    optional<BonjourReply> parse_dns_response(const std::vector<char> &buffer, size_t size);
    std::map<std::string, std::string> parse_txt_records(const std::vector<char> &buffer, size_t size);
};
```

### Device Manager
Implementation: `src/slic3r/GUI/DeviceManager.cpp`

```cpp
class DeviceManager {
public:
    enum ConnectionType {
        CT_FILE = 0,
        CT_CLOUD
    };
    
    struct MachineObject {
        std::string         dev_name;
        std::string         dev_id;
        NetworkAgent*       m_agent {nullptr};
        std::string         connection_type;
        std::string         dev_ip;
        std::string         bind_state;        // "empty", "occupied"
        std::string         bind_user_name;
        std::string         print_state;       // "idle", "prepare", "running", etc.
        std::string         print_stage;       // detailed stage info
        std::string         mc_print_stage;    // machine stage
        std::string         mc_percent;        // print percentage
        std::string         mc_remaining_time; // remaining time
        BBL::PrinterSeries  printer_series;
        std::string         printer_type;
        std::string         nozzle_diameter;
        
        // Status fields
        bool                is_online() const;
        bool                is_in_printing() const;
        bool                is_system_printer() const;
        std::string         get_printer_type_display_str() const;
    };
    
    // Singleton access
    static DeviceManager* GetInstance();
    
    // Machine management
    MachineObject* get_user_machine(std::string dev_id);
    MachineObject* get_my_machine(std::string dev_id);
    std::map<std::string, MachineObject*>* get_my_machine_list();
    
    // Network operations
    int start_discovery(bool start = true, int timeout = 3);
    int connect_printer();
    int disconnect_printer();
    int send_message_to_printer(std::string dev_id, std::string json, int retry = 1);
    
    // Event handling
    int set_on_machine_alive(std::function<void(MachineObject*)> func);
    int set_on_machine_update_status(std::function<void(MachineObject*)> func);
    int set_on_machine_connect(std::function<void(MachineObject*)> func);
    int set_on_machine_disconnect(std::function<void(MachineObject*)> func);
    
private:
    NetworkAgent*       m_agent;
    std::map<std::string, MachineObject*> user_machine_list;
    std::map<std::string, MachineObject*> my_machine_list;
    
    // Event callbacks
    std::function<void(MachineObject*)> machine_alive_fn;
    std::function<void(MachineObject*)> machine_update_status_fn;
    std::function<void(MachineObject*)> machine_connect_fn;
    std::function<void(MachineObject*)> machine_disconnect_fn;
    
    // Internal management
    void parse_user_print_info(std::string body);
    void parse_bind_info(std::string body);
    void update_machine_info(std::string dev_id, std::string info);
};
```

## Real-time Communication

### MQTT Integration
Implementation: Integrated within NetworkAgent

```cpp
class NetworkAgent::MQTTClient {
public:
    // Connection management
    int connect(const std::string& host, int port, const std::string& username, 
               const std::string& password, const std::string& client_id);
    int disconnect();
    bool is_connected() const;
    
    // Messaging
    int publish(const std::string& topic, const std::string& payload, 
               int qos = 0, bool retain = false);
    int subscribe(const std::string& topic, int qos = 0);
    int unsubscribe(const std::string& topic);
    
    // Event handling
    void set_on_connect_callback(std::function<void(int)> callback);
    void set_on_disconnect_callback(std::function<void(int)> callback);
    void set_on_message_callback(std::function<void(const MQTTMessage&)> callback);
    void set_on_publish_callback(std::function<void(int)> callback);
    
    // Quality of Service levels
    enum QoS {
        QOS_AT_MOST_ONCE = 0,   // Fire and forget
        QOS_AT_LEAST_ONCE = 1,  // Acknowledged delivery
        QOS_EXACTLY_ONCE = 2    // Assured delivery
    };
    
private:
    struct MQTTClientImpl;
    std::unique_ptr<MQTTClientImpl> impl;
    
    // Message queuing for offline scenarios
    std::queue<MQTTMessage> pending_messages;
    std::mutex message_queue_mutex;
    
    // Connection state
    std::atomic<bool> connected{false};
    std::string last_error;
    
    // Event callbacks
    std::function<void(int)> on_connect_callback;
    std::function<void(int)> on_disconnect_callback;
    std::function<void(const MQTTMessage&)> on_message_callback;
    std::function<void(int)> on_publish_callback;
};

// MQTT message types for Bambu printers
namespace BambuMQTT {
    struct PrinterStatus {
        std::string print_state;
        float print_progress;
        int remaining_time;
        std::string current_file;
        struct {
            float nozzle_temp;
            float nozzle_target;
            float bed_temp;
            float bed_target;
            float chamber_temp;
        } temperatures;
        std::string error_message;
    };
    
    struct CommandMessage {
        std::string command;
        std::map<std::string, std::variant<std::string, int, float, bool>> parameters;
    };
    
    // Message parsing
    PrinterStatus parse_status_message(const std::string& json_payload);
    std::string serialize_command(const CommandMessage& command);
}
```

### WebSocket Communication
Implementation: `src/slic3r/Utils/WebSocketClient.cpp`

```cpp
class WebSocketClient {
public:
    using MessageHandler = std::function<void(const std::string&)>;
    using ErrorHandler = std::function<void(const std::string&)>;
    using ConnectHandler = std::function<void()>;
    using DisconnectHandler = std::function<void()>;
    
    // Construction
    WebSocketClient();
    ~WebSocketClient();
    
    // Connection management
    bool connect(const std::string& uri);
    void disconnect();
    bool is_connected() const;
    
    // Messaging
    bool send_text(const std::string& message);
    bool send_binary(const std::vector<uint8_t>& data);
    
    // Event handlers
    void set_on_message(MessageHandler handler);
    void set_on_error(ErrorHandler handler);
    void set_on_connect(ConnectHandler handler);
    void set_on_disconnect(DisconnectHandler handler);
    
    // Configuration
    void set_timeout(std::chrono::seconds timeout);
    void set_auto_reconnect(bool enable, std::chrono::seconds interval = std::chrono::seconds(5));
    
private:
    struct WebSocketClientImpl;
    std::unique_ptr<WebSocketClientImpl> impl;
    
    // Connection state
    std::atomic<bool> connected{false};
    std::atomic<bool> auto_reconnect_enabled{false};
    std::chrono::seconds reconnect_interval{5};
    
    // Event handlers
    MessageHandler message_handler;
    ErrorHandler error_handler;
    ConnectHandler connect_handler;
    DisconnectHandler disconnect_handler;
    
    // Internal operations
    void handle_reconnect();
    void process_incoming_message(const std::string& message);
};
```

## Error Handling and Recovery

### Network Error Management
Implementation: Distributed across network components

```cpp
namespace NetworkError {
    enum class ErrorType {
        CONNECTION_FAILED,
        AUTHENTICATION_FAILED,
        TIMEOUT,
        SSL_ERROR,
        DNS_RESOLUTION_FAILED,
        INVALID_RESPONSE,
        RATE_LIMITED,
        QUOTA_EXCEEDED,
        PRINTER_OFFLINE,
        FILE_TOO_LARGE,
        UNSUPPORTED_FORMAT,
        NETWORK_UNREACHABLE
    };
    
    struct NetworkException {
        ErrorType type;
        std::string message;
        int http_status;
        std::string response_body;
        std::chrono::system_clock::time_point timestamp;
        
        NetworkException(ErrorType type, const std::string& message, 
                        int status = 0, const std::string& body = "")
            : type(type), message(message), http_status(status), 
              response_body(body), timestamp(std::chrono::system_clock::now()) {}
    };
    
    class ErrorRecovery {
    public:
        // Retry strategies
        static bool should_retry(const NetworkException& error);
        static std::chrono::milliseconds get_retry_delay(int attempt_count);
        static int get_max_retries(ErrorType error_type);
        
        // Recovery actions
        static void handle_connection_error(const NetworkException& error);
        static void handle_authentication_error(const NetworkException& error);
        static void handle_timeout_error(const NetworkException& error);
        
        // Exponential backoff implementation
        class BackoffTimer {
        public:
            BackoffTimer(std::chrono::milliseconds initial_delay = std::chrono::milliseconds(1000),
                        std::chrono::milliseconds max_delay = std::chrono::minutes(5),
                        double multiplier = 2.0);
            
            std::chrono::milliseconds next_delay();
            void reset();
            
        private:
            std::chrono::milliseconds current_delay;
            std::chrono::milliseconds max_delay;
            double multiplier;
            int attempt_count;
        };
    };
}

// Retry mechanism implementation
template<typename Func>
auto retry_with_backoff(Func&& func, int max_retries = 3) -> decltype(func()) {
    NetworkError::ErrorRecovery::BackoffTimer backoff;
    
    for (int attempt = 0; attempt <= max_retries; ++attempt) {
        try {
            return func();
        } catch (const NetworkError::NetworkException& e) {
            if (attempt == max_retries || !NetworkError::ErrorRecovery::should_retry(e)) {
                throw;
            }
            
            auto delay = backoff.next_delay();
            std::this_thread::sleep_for(delay);
        }
    }
    
    // Should never reach here
    throw std::runtime_error("Retry mechanism failed");
}
```

### Connection Health Monitoring
```cpp
class ConnectionHealthMonitor {
public:
    struct HealthMetrics {
        std::chrono::system_clock::time_point last_successful_operation;
        std::chrono::system_clock::time_point last_error;
        int consecutive_failures;
        double success_rate;
        std::chrono::milliseconds average_response_time;
        
        bool is_healthy() const {
            return consecutive_failures < 3 && success_rate > 0.8;
        }
    };
    
    // Monitoring operations
    void record_success(std::chrono::milliseconds response_time);
    void record_failure(const NetworkError::NetworkException& error);
    HealthMetrics get_health_metrics() const;
    
    // Health checking
    bool is_connection_healthy() const;
    std::chrono::seconds get_recommended_retry_interval() const;
    
    // Callbacks
    using HealthChangeCallback = std::function<void(bool healthy)>;
    void set_health_change_callback(HealthChangeCallback callback);
    
private:
    mutable std::mutex metrics_mutex;
    HealthMetrics current_metrics;
    std::queue<std::chrono::system_clock::time_point> recent_operations;
    HealthChangeCallback health_change_callback;
    
    void update_success_rate();
    void cleanup_old_records();
};
```

## Authentication and Security

### Multi-Protocol Authentication
```cpp
class AuthenticationManager {
public:
    enum class AuthType {
        API_KEY,
        OAUTH2,
        HTTP_DIGEST,
        BEARER_TOKEN,
        BASIC_AUTH,
        CUSTOM
    };
    
    struct Credentials {
        AuthType type;
        std::string primary_token;    // API key, access token, etc.
        std::string secondary_token;  // Refresh token, password, etc.
        std::string username;
        std::chrono::system_clock::time_point expires_at;
        std::map<std::string, std::string> custom_headers;
        
        bool is_expired() const {
            return expires_at < std::chrono::system_clock::now();
        }
    };
    
    // Credential management
    void store_credentials(const std::string& host, const Credentials& creds);
    Credentials get_credentials(const std::string& host) const;
    bool refresh_token(const std::string& host);
    void clear_credentials(const std::string& host);
    
    // HTTP request authentication
    void apply_authentication(Http& http, const std::string& host) const;
    
    // OAuth2 flow support
    struct OAuth2Config {
        std::string client_id;
        std::string client_secret;
        std::string authorization_url;
        std::string token_url;
        std::string redirect_uri;
        std::vector<std::string> scopes;
    };
    
    bool start_oauth2_flow(const std::string& host, const OAuth2Config& config);
    bool complete_oauth2_flow(const std::string& host, const std::string& authorization_code);
    
private:
    std::map<std::string, Credentials> stored_credentials;
    mutable std::shared_mutex credentials_mutex;
    
    // Secure storage (platform-specific)
    void save_credentials_to_secure_storage();
    void load_credentials_from_secure_storage();
    
    // Token refresh
    bool refresh_oauth2_token(const std::string& host, Credentials& creds);
};
```

### SSL/TLS Configuration
```cpp
class SSLManager {
public:
    struct SSLConfig {
        std::string ca_cert_file;
        std::string client_cert_file;
        std::string client_key_file;
        bool verify_peer;
        bool verify_hostname;
        std::vector<std::string> allowed_ciphers;
        std::string protocol_version; // TLS 1.2, 1.3, etc.
    };
    
    // Configuration
    void set_ssl_config(const std::string& host, const SSLConfig& config);
    SSLConfig get_ssl_config(const std::string& host) const;
    
    // Certificate management
    bool validate_certificate(const std::string& host, const std::string& cert_data);
    void pin_certificate(const std::string& host, const std::string& cert_fingerprint);
    bool is_certificate_pinned(const std::string& host) const;
    
    // HTTP client integration
    void configure_http_ssl(Http& http, const std::string& host) const;
    
private:
    std::map<std::string, SSLConfig> ssl_configs;
    std::map<std::string, std::string> pinned_certificates;
    mutable std::shared_mutex config_mutex;
    
    // Certificate validation
    bool verify_certificate_chain(const std::string& cert_chain) const;
    std::string get_certificate_fingerprint(const std::string& cert_data) const;
};
```

## Performance Optimization

### Connection Pooling
```cpp
class ConnectionPool {
public:
    struct Connection {
        std::string host;
        std::unique_ptr<Http> http_client;
        std::chrono::system_clock::time_point last_used;
        bool in_use;
        
        Connection(const std::string& host) 
            : host(host), in_use(false), last_used(std::chrono::system_clock::now()) {}
    };
    
    // Pool management
    std::shared_ptr<Connection> acquire_connection(const std::string& host);
    void release_connection(std::shared_ptr<Connection> connection);
    void cleanup_idle_connections();
    
    // Configuration
    void set_max_connections_per_host(int max_connections);
    void set_idle_timeout(std::chrono::seconds timeout);
    void set_total_max_connections(int max_total);
    
private:
    std::map<std::string, std::vector<std::shared_ptr<Connection>>> connections;
    std::mutex pool_mutex;
    
    int max_connections_per_host = 5;
    int total_max_connections = 50;
    std::chrono::seconds idle_timeout = std::chrono::minutes(5);
    
    void evict_idle_connections();
    bool should_create_new_connection(const std::string& host) const;
};
```

### Upload Optimization
```cpp
class UploadOptimizer {
public:
    struct UploadStrategy {
        enum Type {
            SINGLE_UPLOAD,    // Standard single-part upload
            CHUNKED_UPLOAD,   // Multi-part chunked upload
            RESUMABLE_UPLOAD, // Resumable uploads with progress tracking
            STREAMING_UPLOAD  // Memory-efficient streaming
        };
        
        Type type;
        size_t chunk_size;
        int max_parallel_chunks;
        bool compression_enabled;
        int retry_attempts;
    };
    
    // Strategy selection
    static UploadStrategy select_strategy(size_t file_size, 
                                        const std::string& file_type,
                                        const std::string& host_type);
    
    // Optimized upload implementations
    bool upload_with_strategy(const PrintHostUpload& upload_data,
                             const UploadStrategy& strategy,
                             ProgressFn progress_fn,
                             ErrorFn error_fn) const;
    
private:
    // Strategy implementations
    bool single_upload(const PrintHostUpload& upload_data, ProgressFn progress_fn, ErrorFn error_fn) const;
    bool chunked_upload(const PrintHostUpload& upload_data, const UploadStrategy& strategy,
                       ProgressFn progress_fn, ErrorFn error_fn) const;
    bool resumable_upload(const PrintHostUpload& upload_data, const UploadStrategy& strategy,
                         ProgressFn progress_fn, ErrorFn error_fn) const;
    
    // Compression support
    std::vector<uint8_t> compress_file(const boost::filesystem::path& file_path) const;
    bool should_compress(const std::string& file_extension, size_t file_size) const;
};
```

## Odin Rewrite Considerations

### Architecture Recommendations

**Modern Networking Stack**:
```odin
// Example Odin networking architecture
Network_Client :: struct {
    http_client: ^HTTP_Client,
    websocket_client: ^WebSocket_Client,
    mqtt_client: ^MQTT_Client,
    connection_pool: Connection_Pool,
    auth_manager: Authentication_Manager,
}

Print_Host :: interface {
    connect: proc(config: Print_Host_Config) -> (bool, Error),
    disconnect: proc() -> Error,
    upload_file: proc(file_path: string, options: Upload_Options) -> (Upload_Result, Error),
    get_status: proc() -> (Printer_Status, Error),
    send_command: proc(command: Printer_Command) -> Error,
}

// Async/await style API
upload_file_async :: proc(client: ^Network_Client, file_path: string) -> Future(Upload_Result) {
    // Implementation using Odin's async capabilities
}
```

**Key Improvements**:
1. **Unified API**: Single interface for all print host types
2. **Async/Await**: Modern asynchronous programming patterns
3. **Type Safety**: Stronger typing with Odin's type system
4. **Error Handling**: Explicit error types and handling
5. **Performance**: Native networking without C library dependencies
6. **Security**: Modern TLS 1.3, certificate pinning, secure storage

**Implementation Strategy**:
1. **Phase 1**: Core HTTP client with connection pooling
2. **Phase 2**: Authentication and security systems
3. **Phase 3**: Print host implementations (start with most common)
4. **Phase 4**: Real-time communication (WebSocket, MQTT)
5. **Phase 5**: Cloud service integrations
6. **Phase 6**: Advanced features (discovery, monitoring)

The network printing system represents a complex but well-architected component that would benefit significantly from modernization in an Odin rewrite, with opportunities for improved performance, security, and maintainability.