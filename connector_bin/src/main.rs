use env_logger::{Builder, Env};
use log::LevelFilter;
use log::{error, warn};
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::time::Duration;
use tiktoklive::{
    core::live_client::TikTokLiveClient,
    data::live_common::{ClientData, StreamData, TikTokLiveSettings},
    errors::LibError,
    generated::events::TikTokLiveEvent,
    TikTokLive,
};
use tokio::signal; // Importing signal handling from tokio

#[tokio::main] // Main function is asynchronous and uses tokio runtime
async fn main() {
    init_logger("info"); // Initialize logger with "info" level
                         // Get username from command line arguments
    let user_name = std::env::args().nth(1).expect("No username provided");

    let client = create_client(&user_name); // Create a client for the given username

    let handle = tokio::spawn(async move {
        if let Err(e) = client.connect().await {
            match e {
                LibError::LiveStatusFieldMissing => {
                    warn!("Failed to get live status (probably needs authenticated client): {}", e);
                    let auth_client = create_client_with_cookies(&user_name); // Create an authenticated client
                    if let Err(e) = auth_client.connect().await {
                        error!("Error connecting to TikTok Live after retry: {}", e);
                    }
                }
                LibError::HeaderNotReceived => {
                    error!("Error connecting to TikTok Live: {}", e);
                }

                _ => {
                    // General error case
                    error!("Error connecting to TikTok Live: {}", e);
                }
            }
        }
    });

    signal::ctrl_c().await.expect("Failed to listen for Ctrl+C"); // Wait for Ctrl+C signal to gracefully shut down

    handle.await.expect("The spawned task has panicked"); // Await the spawned task to ensure it completes
}

fn handle_event(client: &TikTokLiveClient, event: &TikTokLiveEvent) {
    match event {
        TikTokLiveEvent::OnConnected(..) => {
            let room_info = client.get_room_info();
            let client_data: ClientData = serde_json::from_str(room_info).unwrap();
            let stream_data: StreamData = serde_json::from_str(&client_data.data.stream_url.live_core_sdk_data.unwrap().pull_data.stream_data).unwrap();
            let video_url = stream_data
                .data
                .ld
                .map(|ld| ld.main.flv)
                .or_else(|| stream_data.data.sd.map(|sd| sd.main.flv))
                .or_else(|| stream_data.data.origin.map(|origin| origin.main.flv))
                .expect("None of the stream types set");
            write_stream_info("/tmp/mpv_ipc", &video_url);
        }

        TikTokLiveEvent::OnMember(join_event) => {
            let nick = &join_event.raw_data.user.nickname;
            append_to_file("/tmp/joins", &format!("{} joined", nick));
        }
        TikTokLiveEvent::OnChat(chat_event) => {
            let nick = &chat_event.raw_data.user.nickname;
            let message = &chat_event.raw_data.content;
            append_to_file("/tmp/chats", &format!("{}: {}", nick, message));
        }
        TikTokLiveEvent::OnGift(gift_event) => {
            if gift_event.raw_data.repeatEnd == 1 || (gift_event.raw_data.repeatEnd == 0 && gift_event.raw_data.gift.type_ != 1) {
                let gift_name = &gift_event.raw_data.gift.name;
                let gifts_amount = gift_event.raw_data.repeatCount as i64;
                append_to_file("/tmp/gifts", &format!("{} sent {} {}", gift_event.raw_data.user.nickname, gifts_amount, gift_name));
            }
        }
        TikTokLiveEvent::OnLike(_like_event) => {}
        _ => {} // Ignore other events
    }
}

fn append_to_file(file: &str, contents: &str) {
    let mut file = OpenOptions::new().append(true).open(file).unwrap();
    writeln!(file, "{}", contents).unwrap();
}

fn write_stream_info(file: &str, contents: &str) {
    let mut file = File::create(file).unwrap();
    writeln!(file, "{}", contents).unwrap();
}

fn init_logger(default_level: &str) {
    let env = Env::default().filter_or("LOG_LEVEL", default_level); // Set default log level from environment or use provided level
    Builder::from_env(env) // Build the logger from environment settings
        .filter_module("tiktoklive", LevelFilter::Debug) // Set log level for tiktoklive module
        .init(); // Initialize the logger
}

fn configure(settings: &mut TikTokLiveSettings) {
    settings.http_data.time_out = Duration::from_secs(12); // Set HTTP timeout to 12 seconds
}

fn configure_with_cookies(settings: &mut TikTokLiveSettings) {
    settings.http_data.time_out = Duration::from_secs(12); // Set HTTP timeout to 12 seconds
    let contents = ""; // Placeholder for cookies
    settings.http_data.headers.insert("Cookie".to_string(), contents.to_string());
    // Insert cookies into HTTP headers
}

fn create_client(user_name: &str) -> TikTokLiveClient {
    TikTokLive::new_client(user_name) // Create a new client
        .configure(configure) // Configure the client
        .on_event(handle_event) // Set the event handler
        .build() // Build the client
}

fn create_client_with_cookies(user_name: &str) -> TikTokLiveClient {
    TikTokLive::new_client(user_name) // Create a new client
        .configure(configure_with_cookies) // Configure the client with cookies
        .on_event(handle_event) // Set the event handler
        .build() // Build the client
}
