# ExCoveralls configuration
# Threshold set to 32% to match CI bash script check (see .github/workflows/ci.yml:91)

[
  minimum_coverage: 32.0,
  treat_no_relevant_lines_as_covered: true,
  skip_files: [
    # Test support files
    "test/support"
  ]
]
