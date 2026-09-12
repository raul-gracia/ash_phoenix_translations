import Config

# Ash >= 3.33 refuses to compile resources unless the string length counting
# strategy is set explicitly. This only affects this library's own dev/test
# resources; consuming applications configure this in their own config.
config :ash, default_string_length_count: :codepoints
