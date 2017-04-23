# https://github.com/alexeyxo/protobuf-swift
echo "generating ios+osx code..."
protoc  wire.proto --swift_out=./apple/common

# https://github.com/golang/protobuf
echo "generating golang code..."
protoc  wire.proto --swift_out=./apple/common
protoc --go_out=./server/src/main wire.proto

echo "done!"
