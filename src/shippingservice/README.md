# Shipping Service

The Shipping service provides price quote, tracking IDs, and the impression of order fulfillment & shipping processes.

## Dependencies

Dependencies are managed with Go modules (`go.mod` and `go.sum`):

```bash
go mod download
```

## Build

From `src/shippingservice`, run:

```bash
docker build ./
```

## Test

```bash
go test ./...
```
