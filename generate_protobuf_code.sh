function generate() {

	echo $1":"
	# https://github.com/alexeyxo/protobuf-swift

	if [ "$2" ] # server also gets a protobuf file
	then
		# https://github.com/golang/protobuf
		echo "generating golang code..."
		protoc --go_out=./server/src/main $1.proto
	fi

	echo "generating swift code..."
	protoc $1.proto --swift_out=./apple/common

	# https://github.com/square/wire
	echo "generating java code..."
	java -jar android/protobuf/wire-compiler-2.3.0-RC1-jar-with-dependencies.jar \
    	--proto_path=. \
    	--java_out=android/app/src/main/java/ \
    	--android \
    	$1.proto
}

echo
generate wire true
echo
generate voip
echo "\ndone!\n"
