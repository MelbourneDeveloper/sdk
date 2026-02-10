# Build the runtime first (required before running tests)
./tools/build.py -m release runtime

# Run all record spread tests (runtime + error multi-tests)
./tools/test.py -mrelease --runtime=vm tests/language/record_spreads/