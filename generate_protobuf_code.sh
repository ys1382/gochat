# https://github.com/alexeyxo/protobuf-swift
echo "generating swift code..."
protoc wire.proto --swift_out=./apple/common

# https://github.com/golang/protobuf
echo "generating golang code..."
protoc --go_out=./server/src/main wire.proto

# https://github.com/square/wire
echo "generating java code..."
java -jar android/protobuf/wire-compiler-2.3.0-RC1-jar-with-dependencies.jar \
    --proto_path=. \
    --java_out=android/app/src/main/java/ \
    --android \
    wire.proto

echo "done!"
