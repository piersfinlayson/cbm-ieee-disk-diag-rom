/// Support program for the IEEE Diagnostics ROM
/// 
/// Handles communication with the ROM

use std::thread;
use std::time::Duration;
use clap::{Parser, Subcommand};
use xum1541::{BusBuilder, DeviceChannel, Error};

#[derive(Parser)]
#[clap(author, version, about = "Communicates with IEEE-488 devices")]
struct Cli {
    #[clap(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Send a single character to device on channel 15
    Send {
        /// Character to send
        char: String,
        
        /// Number of times to send the character
        #[clap(default_value = "1")]
        iterations: u32,

        /// Device to communicate with (default: 8)
        #[clap(default_value = "8")]
        device: u8,
    },
    
    /// Tell device to talk on specified channel and receive data
    Recv {
        /// Channel to receive from (default: 0)
        #[clap(default_value = "0")]
        channel: u8,

        /// Device to communicate with (default: 8)
        #[clap(default_value = "8")]
        device: u8,
    },
}

fn main() -> Result<(), Error> {
    let cli = Cli::parse();
    
    // Connect to the XUM1541 device via USB
    let mut bus = BusBuilder::new().build().unwrap_or_else(|e| {
        eprintln!("Failed to connect to bus");
        eprintln!("Error details: {}", e);
        std::process::exit(1);
    });

    // Initialize the bus
    bus.initialize().unwrap_or_else(|e| {
        eprintln!("Failed to initialize bus");
        eprintln!("Error details: {}", e);
        std::process::exit(1);
    });

    match &cli.command {
        Commands::Send { char, iterations, device } => {
            // Get the first character
            let char_to_send = char.chars().next().unwrap_or_else(|| {
                eprintln!("Error: Empty character argument");
                std::process::exit(1);
            });

            // Set pause between iterations
            let pause_millis = 100;

            if *iterations == 1 {
                println!("Sending character '{}' to device {} on channel 15", device, char_to_send);
            } else {
                println!(
                    "Sending character '{}' to device {} on channel 15 {} times, pausing {}ms between each iteration",
                    device, char_to_send, iterations, pause_millis
                );
            }

            // Send the character to the drive the specified number of times
            for ii in 0..*iterations {
                // Instruct device to talk using the specified channel
                bus.listen(DeviceChannel::new(*device, 15)?)?;

                // Write a byte
                let data = [char_to_send as u8];
                bus.write(&data)?;

                // Print it out
                println!("Iteration {}: Char sent {}", ii + 1, char_to_send);

                // Tell the drive to stop talking
                bus.unlisten()?;

                // Add pause between iterations (skip on last iteration)
                if ii < iterations - 1 {
                    thread::sleep(Duration::from_millis(pause_millis));
                }
            }

            // Retrieve status from device
            let data_str = read(&mut bus, *device, 15)?;

            println!("ROM status: {}", data_str);
        },
        Commands::Recv { channel, device } => {
            println!("Receiving data from device {} on channel {}", device, channel);

            let data_str = read(&mut bus, *device, *channel)?;

            println!("Received data: {}", data_str);
        },
    }

    Ok(())
}

fn read(bus: &mut xum1541::Bus, device: u8, channel: u8) -> Result<String, Error> {
    bus.talk(DeviceChannel::new(device, channel)?)?;

    let mut data = [0u8; 256];
    bus.read(&mut data)?;
    
    // Convert to string, propagating error to caller instead of exiting
    Ok(match std::str::from_utf8(&data) {
        Ok(data_str) => {
            // Trim null characters from the end
            let trimmed_str = data_str.trim_matches(|c| c == '\0');
            trimmed_str.to_string()
        },
        Err(e) => {
            eprintln!("Error converting data to string: {}", e);
            "".to_string()
        }
    })
}