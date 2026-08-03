# Pin the Dart SDK version for reproducible builds (requires SDK >= 3.8.0).
FROM dart:3.12 AS build

# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed.
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# Build a minimal image from the AOT-compiled binary and the required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

# Run the action once per invocation.
ENTRYPOINT ["/app/bin/server"]
