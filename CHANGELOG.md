# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.13.3]
- modifies `queuebus:unsubscribe` to decommission only the specified application when passed exactly one argument.

## [0.13.2]

### Fixes

- Properly passes the attributes down to the subscription when using `on_heartbeat`

## [0.13.1]

### Fixes

- Allows matching on 0 via the `on_heartbeat` subscription

### Added

- Allows matching on `wday` via the `on_heartbeat` subscription

## [0.13.0]

### Added

- Adds `Dispatch#on_heartbeat` which is a helper function for specifying heartbeat subscriptions.

## [0.12.0]

### Changed
- Pipelines fetching all queue subscriptions when using `QueueBus::Application.all`

## [0.11.0]

### Added

- Adds `QueueBus.in_context` method. Useful when working with a multithreaded environment to add a description for all events published within this scope.

## [0.10.0]

### Added
- Ability to unsubscribe from specific queues in an application (`Application#unsubscribe_queue`).
- `rake queuebus:unsubscribe` can now take two parameters to unsubscribe from specific queues, e.g. `rake queuebus:unsubscribe[my_app_key, my_queue_name]`.

## [0.9.1]

### Added
- Documented some of the major classes and modules

### Fixed
- Ran the rubocop autocorrect on the entire codebase.
- Fixed issue that prevented heartbeat events from firing under certain conditions

## [0.9.0]

### Added
- Adds rake tasks to list scheduled jobs as csv

## [0.8.1]

### Fixed
- `with_local_mode` breaks subsequent calls to `local_mode` on versions less than 2.6.

## [0.8.0]

### Added
- Adds `QueueBus.with_local_mode` method. Useful when working with a multithreaded environment.

## [0.7.0]

### Added
- Adds `QueueBus.has_adapter?` to check whether the adapter is set.

### Changed
- Now uses `Process.hostname` to determine hostname versus relying on unix shell.
- Rubocop is now a dev dependency.
- Accessors to config are now done with actual attrs.
- Logging with the adapter will use the logger if present.

### Fixed
- Passing a class to `adapter=` would error on a `NameError`.

## [0.6.0]

### Added
- New middleware implementation that allows middleware to wrap the execution of work from the `QueueBus::Worker`
- Changelog!

### Changed
- Specs are now using the `expect` syntax instead of `should`. This more closely aligns with the rspec recommendations.
