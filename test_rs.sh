# Build the runtime first (required before running tests)
./tools/build.py -m release runtime

# Run runtime tests (basic, const, evaluation_order, inference)
./tools/test.py -mrelease --runtime=vm tests/language/record_spreads/

# Run static error tests (needs fasta compiler, not vm runtime)
./tools/test.py -mrelease --compiler=fasta tests/language/record_spreads/record_spread_error_test.dart