# Exclude Redis tests by default since Redis backend is deferred to future release
ExUnit.start(exclude: [:redis])
