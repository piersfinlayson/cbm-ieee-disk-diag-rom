use std::thread;
use std::time::Duration;
/// listen.rs
///
/// Allows you to send single char commands to to channel 15 via an attached
/// IEEE-488 xum1541/ZoomFloppy to drive the IEEE-488 diagnostics ROM.
///
/// Can optionally be used to
use xum1541::{BusBuilder, DeviceChannel, Error};

fn main() -> Result<(), Error> {
    //
    // Parse command line arguments
    //

    // Parse first command line argument (character to send)
    let arg = std::env::args().nth(1).unwrap_or_else(|| {
        eprintln!(
            "Usage: {} <char> [iterations]",
            std::env::args().next().unwrap_or_default()
        );
        std::process::exit(1);
    });

    // Parse help argument
    if arg.starts_with('-') {
        if arg == "--help" || arg == "-h" || arg == "-?" {
            eprintln!(
                "Usage: {} <char> [iterations]",
                std::env::args().next().unwrap_or_default()
            );
            eprintln!("Send a single character to the drive on device 8 via channel 15.");
            eprintln!("If no iterations are specified, it defaults to 1.");
            std::process::exit(0);
        } else {
            eprintln!("Error: Invalid argument '{}'", arg);
            std::process::exit(1);
        }
    }

    // Get the first character
    let char_to_send = arg.chars().next().unwrap_or_else(|| {
        eprintln!("Error: Empty character argument");
        std::process::exit(1);
    });

    // Parse second command line argument (iterations)
    let iterations = std::env::args()
        .nth(2)
        .and_then(|s| s.parse::<u32>().ok())
        .unwrap_or(1); // Default to 1 if not specified

    // Set pause between iterations
    let pause_millis = 100;

    if iterations == 1 {
        println!("Sending character '{}' to device 8 on channel 15", char_to_send);
    } else {
        println!(
            "Sending character '{}' to device 8 on channel 15 {} times, pausing {}ms between each iteration",
            char_to_send, iterations, pause_millis
        );
    }

    //
    // Communicate with the bus
    //

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

    // Tell the drive on device 8 to talk using channel 15
    bus.talk(DeviceChannel::new(8, 15)?)?;

    // Read up to 256 bytes of data (this will read drive status)
    let mut data = vec![0u8; 256];
    bus.read(&mut data)?;
    let data_str = std::str::from_utf8(&data).unwrap_or_else(|e| {
        eprintln!("Failed to convert data into string {}", e);
        std::process::exit(1);
    });
    println!("IEEE Diagnostics ROM status: {}", data_str);

    // Send the character to the drive the specified number of times
    for ii in 0..iterations {
        // Instruct device 8 to talk using the specified channel
        bus.listen(DeviceChannel::new(8, 15)?)?;

        // Write a byte
        let data = [char_to_send as u8];
        bus.write(&data)?;

        // Print it out (this should be the drive status)
        println!("Iteration {}: Char sent {}", ii + 1, char_to_send);

        // Tell the drive to stop talking
        bus.unlisten()?;

        // Add 50ms pause between iterations (skip on last iteration)
        if ii < iterations - 1 {
            thread::sleep(Duration::from_millis(pause_millis));
        }
    }

    Ok(())
}
