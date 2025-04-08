# Changelog

## 0.1.2

Substantial rewrite, including:
- Splitting RAM test into two
- Taking control of the 6504 after main RAM test, before before testing key shared RAM used by 6504 ROM routine - also allows detecting of failed 6504 and related components
- Introduced two stage build process in order to separately compile, and then include, the code which will be executed by the 6504.
- Better zero page management
- Moving RAM test patterns to be table driven for better extensibility
- Retrieve device ID early on in processing
- Adding ability to detetct and report multiple errors, and device ID 
 - Tidying up main, stack supported, code making it easier to see overall program execution flow - see with_stack_main:

## 0.1.1

- Added failed SRAM nibble detection and reporting

## 0.1.0

- First release