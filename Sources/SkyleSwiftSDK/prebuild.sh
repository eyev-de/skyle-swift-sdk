#!/bin/bash

#  prebuild.sh
#  Skyle
#
#  Created by Konstantin Wachendorff on 24.06.20.
#  Copyright © 2020 eyeV GmbH.

# exec > "${PROJECT_DIR}/prebuild.log" 2>&1 "${PROJECT_DIR}/Sources/SkyleSwiftSDK/prebuild.sh"

timestamp() {
  date +"%T"
}

GRPC_SWIFT_DIR="${PROJECT_DIR}/.build/checkouts/grpc-swift/"
cd $GRPC_SWIFT_DIR
DIR="${BUILD_DIR}/.build/checkouts/grpc-swift/.build/release/"
if [ -d "$DIR" ]; then
  echo "Skipping make and make plugins..."
else
    echo "Executing make and make plugins in $GRPC_SWIFT_DIR"
    echo "This sometimes failes, just start the build process again."
    make
    make plugins
fi

echo "[$(timestamp)]: Generating files..."
protoc ${PROJECT_DIR}/Skyle.proto/Skyle.proto \
--proto_path=${PROJECT_DIR}/Skyle.proto/ \
--plugin=${PROJECT_DIR}/.build/checkouts/grpc-swift/.build/release/protoc-gen-swift \
--swift_opt=Visibility=Public \
--swift_out=${PROJECT_DIR}/Sources/SkyleSwiftSDK/Protos/ \
--plugin=${PROJECT_DIR}/.build/checkouts/grpc-swift/.build/release/protoc-gen-grpc-swift \
--grpc-swift_opt=Visibility=Public \
--grpc-swift_out=${PROJECT_DIR}/Sources/SkyleSwiftSDK/Protos/
echo "Finished."
