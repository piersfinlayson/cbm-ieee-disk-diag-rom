# IEEE-488 Disk Drive Hardware Test Specification

## 1. Introduction

This document specifies a hardware diagnostic procedure for testing IEEE-488 interface components on a Commodore disk drive before initializing the full IEEE-488 protocol stack. The test is designed to:

- Identify faulty hardware lines individually
- Work with any combination of working/broken lines
- Maintain minimal code footprint on both sides
- Report detailed diagnostics for later retrieval

## 2. Hardware Background

The IEEE-488 interface in the disk drive consists of two primary chips:

- **UC1 (6532)**: Handles DIO1-8 data lines (bidirectional)
    - PB0-PB7: outputs (DO0-DO7)
    - PA0-PA7: inputs (DI0-DI7)
- **UE1 (6532)**: Handles control lines:
    - ATN (input only to drive)
        - PA7 ~ATN (input only, IRQ driven) - M bit
        - PA0 ATNA (output, not quite sure of purpose, but think it helps MC3446 chips decide who drives the bus)
    - DAV (bidirectional)
        - PA6 - input (DAVI) - V bit
        - PA4 - output (DAVO)
    - EOI (bidirectional)
        - PA5 input (EOII)
        - PA3 output (EOIO)
    - NRFD (bidirectional)
        - PB7 input (RFDI) - M bit
        - PA2 output (RFDO)
    - NDAC (bidirectional)
        - PB6 input (DACI) - V bit
        - PA1 output (DACO)
    - IFC (tied to reset, not testable)

## 3. Testing Philosophy

The test follows these core principles:

1. **Separate chip testing**: UC1 and UE1 are tested independently
2. **Self-establishing protocol**: Each phase uses successfully tested lines
3. **Symmetric implementation**: Both sides follow similar logic for simplicity
4. **Progressive resilience**: More comprehensive tests follow successful basic tests
5. **Complete status collection**: Records both send/receive capabilities of each line

## 4. Test Protocol Specification

### 4.1 UC1 Testing (DIO Lines)

#### 4.1.1 Initial Handshake

**Forward Direction:**
1. DUT sets DIO1 high, all others low
2. Controller detects DIO1 high, verifies all other lines are low, sets DIO2 high
3. DUT detects DIO2 high, verifies all other lines except DIO1 are low, sets DIO3 high
4. Controller detects DIO3 high, verifies all other lines except DIO2 are low, sets DIO4 high
5. DUT detects DIO4 high, verifies all other lines except DIO3 are low, sets DIO5 high
6. Controller detects DIO5 high, verifies all other lines except DIO4 are low, sets DIO6 high
7. DUT detects DIO6 high, verifies all other lines except DIO5 are low, sets DIO7 high
8. Controller detects DIO7 high, verifies all other lines except DIO6 are low, sets DIO8 high
9. DUT detects DIO8 high, verifies all other lines except DIO7 are low, sets DIO1 low
10. Controller detects DIO1 low, sets DIO2 low

**Reverse Direction:**

11. DUT sets DIO8 high, all others low
12. Controller detects DIO8 high, verifies all other lines are low, sets DIO7 high
13. DUT detects DIO7 high, verifies all other lines except DIO8 are low, sets DIO6 high
14. Controller detects DIO6 high, verifies all other lines except DIO7 are low, sets DIO5 high
15. DUT detects DIO5 high, verifies all other lines except DIO6 are low, sets DIO4 high
16. Controller detects DIO4 high, verifies all other lines except DIO5 are low, sets DIO3 high
17. DUT detects DIO3 high, verifies all other lines except DIO4 are low, sets DIO2 high
18. Controller detects DIO2 high, verifies all other lines except DIO3 are low, sets DIO1 high
19. DUT detects DIO1 high, verifies all other lines except DIO2 are low, moves to pattern testing

**Fallback**: If handshake fails at any point, record failure for that line and continue with the rest.

#### 4.1.2 DIO Lines Pattern Testing

After handshake, run pattern tests using working lines identified during handshake:

1. Select a working DIO line as "sync" line (preferably DIO8)
2. DUT sets pattern on DIO1-7 (excluding sync line)
3. DUT toggles sync line (high-low-high) to signal "pattern ready"
4. Controller reads pattern
5. Controller toggles sync line (high-low-high) to acknowledge
6. Repeat with patterns: 0x55, 0xAA, 0xFF, 0x00
7. Controller sets pattern on DIO1-7
8. Controller toggles sync line to signal
9. DUT reads pattern
10. DUT toggles sync line to acknowledge
11. Repeat with patterns: 0x55, 0xAA, 0xFF, 0x00

#### 4.1.3 No Working Lines Fallback

If no DIO lines are found working:
1. Skip remaining DIO tests
2. Move directly to UE1 control line testing
3. Record all DIO lines as failed

### 4.2 UE1 Testing (Control Lines)

#### 4.2.1 Initial Control Line Handshake

**Forward Direction:**
1. DUT sets NRFD high, all others low
2. Controller detects NRFD high, verifies all other control lines are low, sets NDAC high
3. DUT detects NDAC high, verifies all other control lines except NRFD are low, sets DAV high
4. Controller detects DAV high, verifies all other control lines except NDAC are low, sets EOI high
5. DUT detects EOI high, verifies all other control lines except DAV are low, sets NRFD low
6. Controller detects NRFD low, sets NDAC low

**Reverse Direction:**

7. DUT sets EOI high, all others low
8. Controller detects EOI high, verifies all other control lines are low, sets DAV high
9. DUT detects DAV high, verifies all other control lines except EOI are low, sets NDAC high
10. Controller detects NDAC high, verifies all other control lines except DAV are low, sets NRFD high
11. DUT detects NRFD high, verifies all other control lines except NDAC are low - handshake complete

**Fallback**: If handshake fails at any point, try each line individually:
1. Toggle each control line high-low-high
2. Monitor all other control lines for any response
3. Use any responsive line to establish basic communication

#### 4.2.2 ATN Line Testing

Since ATN is input-only to the drive:
1. Use a successfully tested line as "sync" (e.g., NRFD)
2. DUT toggles sync line to request ATN test
3. Controller toggles ATN high-low-high-low-high
4. DUT records if ATN transitions were detected correctly
5. DUT toggles sync line to acknowledge test completion

#### 4.2.3 Bidirectional Control Line Testing

For each bidirectional control line (DAV, EOI, NRFD, NDAC):
1. Use a successfully tested line as "sync"
2. DUT sets test line high
3. DUT toggles sync line to signal
4. Controller verifies test line state
5. Controller toggles sync line to acknowledge
6. DUT sets test line low
7. DUT toggles sync line to signal
8. Controller verifies test line state
9. Controller toggles sync line to acknowledge

Then reverse direction:
1. Controller sets test line high
2. Controller toggles sync line to signal
3. DUT verifies test line state
4. DUT toggles sync line to acknowledge
5. Controller sets test line low
6. Controller toggles sync line to signal
7. DUT verifies test line state
8. DUT toggles sync line to acknowledge

## 5. Data Structures

### 5.1 DUT Test Results Storage

Results are stored by test type rather than by line to conserve memory:

```
RESULT_IEEE_DIO_SET_HIGH:    (1 byte) Bit 0-7 = DIO1-8 can be set HIGH
RESULT_IEEE_DIO_SET_LOW:     (1 byte) Bit 0-7 = DIO1-8 can be set LOW
RESULT_IEEE_DIO_DETECT_HIGH: (1 byte) Bit 0-7 = DIO1-8 can detect HIGH
RESULT_IEEE_DIO_DETECT_LOW:  (1 byte) Bit 0-7 = DIO1-8 can detect LOW
RESULT_IEEE_DIO_SHORT:       (1 byte) Bit 0-7 = DIO1-8 has short with another line

RESULT_IEEE_CTRL_SET_HIGH:   (1 byte) Bit 0-3 = NRFD,NDAC,DAV,EOI can be set HIGH
RESULT_IEEE_CTRL_SET_LOW:    (1 byte) Bit 0-3 = NRFD,NDAC,DAV,EOI can be set LOW
RESULT_IEEE_CTRL_DETECT_HIGH: (1 byte) Bit 0-4 = NRFD,NDAC,DAV,EOI,ATN can detect HIGH
RESULT_IEEE_CTRL_DETECT_LOW:  (1 byte) Bit 0-4 = NRFD,NDAC,DAV,EOI,ATN can detect LOW
RESULT_IEEE_CTRL_SHORT:      (1 byte) Bit 0-4 = NRFD,NDAC,DAV,EOI,ATN has short with another line
```

This requires 10 bytes total instead of 13, and makes it easier to check specific test results by directly using the bit positions that correspond to each line.

### 5.2 Test State Machine

DUT maintains a simple state machine:
```
0: Idle/Ready
1: UC1 DIO handshake
2: UC1 DIO pattern testing
3: UE1 control line handshake
4: UE1 control line testing
5: Testing complete
```

## 6. Implementation Notes

### 6.1 6502 Assembly (DUT Side)

#### 6.1.1 Key Memory Locations
- Zero Page variables for test state:
  - TEST_STATE: Current test state (0-5)
  - TEST_LINE: Current line being tested
  - TEST_TIMEOUT_L: Timeout counter low byte
  - TEST_TIMEOUT_H: Timeout counter high byte
  
- Results storage variables:
  - RESULT_IEEE_DIO_SET_HIGH: DIO lines can be set high
  - RESULT_IEEE_DIO_SET_LOW: DIO lines can be set low
  - RESULT_IEEE_DIO_DETECT_HIGH: DIO lines can detect high
  - RESULT_IEEE_DIO_DETECT_LOW: DIO lines can detect low
  - RESULT_IEEE_DIO_SHORT: DIO lines have shorts
  - RESULT_IEEE_CTRL_SET_HIGH: Control lines can be set high
  - RESULT_IEEE_CTRL_SET_LOW: Control lines can be set low
  - RESULT_IEEE_CTRL_DETECT_HIGH: Control lines can detect high
  - RESULT_IEEE_CTRL_DETECT_LOW: Control lines can detect low
  - RESULT_IEEE_CTRL_SHORT: Control lines have shorts

#### 6.1.2 Test Timing
- Use the existing `delay` routine which takes X as an argument and delays for roughly 1/256th of a second
- For timeouts, call `delay` with appropriate value (e.g., X=128 for ~0.5 second)
- If expected response not received after timeout, mark line as failed and continue

#### 6.1.3 Implementation Approach
- Use bit set/clear operations for manipulating lines
- Implement one state machine per test phase
- After testing, store results for later retrieval via IEEE-488 TALK

### 6.2 Controller Implementation

#### 6.2.1 PET BASIC Implementation
- Use PEEK/POKE to directly access IEEE-488 registers
- Implement timeout using FOR/NEXT loops
- Use WAIT commands for monitoring line state changes

Example structure:
```basic
100 REM IEEE-488 TEST CONTROLLER
110 REM INITIALIZE
120 POKE 59456,0  'Clear all lines
...
1000 REM DIO HANDSHAKE ROUTINE
1010 WAIT 59456,1 'Wait for DIO1 high
1020 POKE 59456,2 'Set DIO2 high
...
```

#### 6.2.2 Rust/xum1541 Implementation
- Use the xum1541 USB-IEEE-488 adapter API
- Implement proper error handling and timeouts
- Structure as a state machine with clear separation of concerns

Example structure:
```rust
enum TestState {
    Idle,
    DioHandshake(u8),  // Current line being tested
    DioPatternTest(u8),  // Current pattern index
    ControlHandshake(u8),  // Current line being tested
    ControlLineTest(u8),  // Current line being tested
    Complete,
}

struct IEEE488Tester {
    state: TestState,
    device: Xum1541Device,
    results: [u8; 13],
}

impl IEEE488Tester {
    fn run_test(&mut self) {
        loop {
            match self.state {
                TestState::Idle => self.start_dio_handshake(),
                TestState::DioHandshake(line) => self.process_dio_handshake(line),
                // ...other states
            }
            
            if let TestState::Complete = self.state {
                break;
            }
        }
    }
    
    fn process_dio_handshake(&mut self, line: u8) {
        // Implementation
    }
    
    // Other methods...
}
```

## 7. Result Interpretation and Error Reporting

### 7.1 IEEE-488 TALK Results

Results retrieved via IEEE-488 TALK command after test completion:

1. Each result byte represents a test type (see Data Structures)
2. For each line, check the corresponding bit position:
   - If bit is set in SET_HIGH and SET_LOW: Line can be fully set by DUT
   - If bit is set in DETECT_HIGH and DETECT_LOW: Line can be fully read by DUT
   - If bit is set in SHORT: Line has a short with another line

Example interpretation:
```
RESULT_IEEE_DIO_SET_HIGH: 0xFF - All DIO lines can be set high
RESULT_IEEE_DIO_SET_LOW: 0xFE - All DIO lines except DIO1 can be set low
RESULT_IEEE_DIO_DETECT_HIGH: 0x7F - All DIO lines except DIO8 can detect high
RESULT_IEEE_DIO_SHORT: 0x0C - DIO3 and DIO4 have shorts with other lines
```

### 7.2 LED Error Reporting

If IEEE testing fails, errors are reported via LED flash codes:

1. **UC1 (DIO line) failures**:
   - DR0 LED remains lit solid
   - ERR LED flashes a pattern to indicate which DIO line(s) failed:
     - 1 flash: DIO1-2
     - 2 flashes: DIO3-4
     - 3 flashes: DIO5-6
     - 4 flashes: DIO7-8
   - Multiple flash sequences for multiple failures

2. **UE1 (Control line) failures**:
   - DR1 LED remains lit solid
   - ERR LED flashes a pattern to indicate which control line(s) failed:
     - 1 flash: NRFD
     - 2 flashes: NDAC
     - 3 flashes: DAV
     - 4 flashes: EOI
     - 5 flashes: ATN
   - Multiple flash sequences for multiple failures

## 8. Testing Flow Diagram

```
+----------------+     +---------------+     +-------------------+
| Start DIO Test |---->| DIO Handshake |---->| DIO Pattern Tests |
+----------------+     +---------------+     +-------------------+
                           |                           |
                           v                           v
                      +-----------+              +-------------+
                      | DIO Error |              | Record Data |
                      +-----------+              +-------------+
                           |                           |
                           v                           v
              +---------------------------+    +----------------------+
              | Start Control Line Tests  |<---| Control Handshake   |
              +---------------------------+    +----------------------+
                           |                           |
                           v                           v
                  +----------------+          +-------------------+
                  | ATN Line Tests |--------->| Bidirectional     |
                  +----------------+          | Control Line Tests|
                                              +-------------------+
                                                      |
                                                      v
                                              +-------------------+
                                              | Record Results    |
                                              +-------------------+
                                                      |
                                                      v
                                              +-------------------+
                                              | Test Complete     |
                                              +-------------------+
```

## 9. Timeout Handling

1. Each test phase has a defined timeout (500ms recommended)
2. If an expected response is not received within timeout:
   - Mark the line as failed
   - Try to continue with other lines
   - If critical lines for a phase fail, skip to next phase

## 10. IEEE-488 Pinout Reference

| Pin | Signal | Direction (from DUT perspective) |
|-----|--------|----------------------------------|
| 1   | DIO1   | Bidirectional                    |
| 2   | DIO2   | Bidirectional                    |
| 3   | DIO3   | Bidirectional                    |
| 4   | DIO4   | Bidirectional                    |
| 5   | EOI    | Bidirectional                    |
| 6   | DAV    | Bidirectional                    |
| 7   | NRFD   | Bidirectional                    |
| 8   | NDAC   | Bidirectional                    |
| 9   | IFC    | Input (tied to reset)            |
| 10  | SRQ    | Not tested                       |
| 11  | ATN    | Input                            |
| 12  | SHIELD | N/A                              |
| 13  | DIO5   | Bidirectional                    |
| 14  | DIO6   | Bidirectional                    |
| 15  | DIO7   | Bidirectional                    |
| 16  | DIO8   | Bidirectional                    |
| 17-24| GND   | N/A                              |

## 11. Notes for Implementation

1. **Always implement proper error recovery**:
   - If any phase fails, try to fallback to simpler tests
   - Store "best effort" results even if complete testing impossible

2. **State transitions should be clear**:
   - Use fixed state codes on both sides
   - Implement defensive programming with timeouts

3. **All line operations should be idempotent**:
   - Multiple attempts to set a line should not cause issues
   - Pattern tests should be repeatable

4. **Minimize external dependencies**:
   - Controller code should work with minimal libraries
   - DUT code should be standalone ROM-able

5. **Keep timing simple**:
   - Use the built-in delay routine
   - Avoid complex timing dependencies between sides